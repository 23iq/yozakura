package routines

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/brand"

	"github.com/stretchr/testify/assert"
)

func TestNormalize(t *testing.T) {
	r, err := Normalize(Routine{Name: "  Morning start! ", Steps: []Step{
		{Kind: "action", Action: " media.next ", Tool: "x"},
		{Kind: "delay", Ms: 500, Args: map[string]any{"a": 1}},
		{Kind: "tool", Tool: "dnd_set", Args: map[string]any{"enabled": true}},
	}})
	assert.NoError(t, err)
	assert.Equal(t, "morning-start", r.ID)
	assert.Equal(t, "lightning", r.Icon)
	assert.Equal(t, "media.next", r.Steps[0].Action)
	assert.Empty(t, r.Steps[0].Tool)
	assert.Nil(t, r.Steps[1].Args)

	for _, bad := range []Routine{
		{Name: ""},
		{Name: "x", Steps: []Step{{Kind: "action"}}},
		{Name: "x", Steps: []Step{{Kind: "tool"}}},
		{Name: "x", Steps: []Step{{Kind: "tool", Tool: "routine_run"}}},
		{Name: "x", Steps: []Step{{Kind: "delay", Ms: 0}}},
		{Name: "x", Steps: []Step{{Kind: "delay", Ms: MaxDelayMs + 1}}},
		{Name: "x", Steps: []Step{{Kind: "dance"}}},
	} {
		_, err := Normalize(bad)
		assert.Error(t, err, "%+v", bad)
	}
	many := Routine{Name: "x"}
	for i := 0; i < 4; i++ {
		many.Steps = append(many.Steps, Step{Kind: "delay", Ms: MaxDelayMs})
	}
	_, err = Normalize(many)
	assert.ErrorContains(t, err, "add up")
}

func TestFindAndUniqueID(t *testing.T) {
	list := []Routine{{ID: "morning", Name: "Morning"}, {ID: "focus-time", Name: "Focus time"}}
	assert.Equal(t, 0, Find(list, "morning"))
	assert.Equal(t, 1, Find(list, "FOCUS TIME"))
	assert.Equal(t, 1, Find(list, "Focus-Time!"))
	assert.Equal(t, -1, Find(list, "evening"))
	assert.Equal(t, "morning-2", UniqueID(list, "morning", -1))
	assert.Equal(t, "morning", UniqueID(list, "morning", 0))
	assert.Equal(t, "evening", UniqueID(list, "evening", -1))
}

func TestStoreRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sub", FileName)
	list, err := Load(path)
	assert.NoError(t, err)
	assert.Empty(t, list)
	assert.NoError(t, Save(path, []Routine{{ID: "a", Name: "A", Steps: []Step{{Kind: KindDelay, Ms: 10}}}}))
	list, err = Load(path)
	assert.NoError(t, err)
	assert.Equal(t, "A", list[0].Name)
	assert.Equal(t, 10, list[0].Steps[0].Ms)
}

func TestActionArgv(t *testing.T) {
	argv, err := ActionArgv("media.next", nil)
	assert.NoError(t, err)
	assert.Equal(t, []string{"sh", "-c", "playerctl next"}, argv)

	argv, err = ActionArgv("window.close", nil)
	assert.NoError(t, err)
	assert.Equal(t, []string{brand.Daemon, "window", "close"}, argv)

	argv, err = ActionArgv("workspace.switch", map[string]any{"index": "3"})
	assert.NoError(t, err)
	assert.Equal(t, []string{brand.Daemon, "workspace", "switch", "3"}, argv)

	// Defaults fill missing args.
	argv, err = ActionArgv("window.focus", nil)
	assert.NoError(t, err)
	assert.Equal(t, []string{brand.Daemon, "window", "focus-dir", "u"}, argv)

	argv, err = ActionArgv("apps.launch", map[string]any{"app": "firefox"})
	assert.NoError(t, err)
	assert.Equal(t, "sh", argv[0])
	assert.Contains(t, argv[2], "launch")

	_, err = ActionArgv("window.drag", nil)
	assert.ErrorContains(t, err, "only works from a keybind")
	_, err = ActionArgv("nope.nope", nil)
	assert.Error(t, err)
	_, err = ActionArgv("command.run", nil)
	assert.ErrorContains(t, err, "nothing to run")
}

type fakeExec struct {
	argv  [][]string
	tools []string
	slept time.Duration
	fail  string
}

func (f *fakeExec) executor(lookup func(string) (Routine, bool)) Executor {
	return Executor{
		Exec: func(_ context.Context, argv []string) (string, error) {
			f.argv = append(f.argv, argv)
			if f.fail != "" && strings.Contains(strings.Join(argv, " "), f.fail) {
				return "boom", errors.New("exit status 1")
			}
			return "ok", nil
		},
		Tool: func(_ context.Context, name string, args map[string]any) (string, bool, error) {
			f.tools = append(f.tools, name)
			if name == "bad_tool" {
				return "no such thing\nmore", true, nil
			}
			return `{"done":true}`, false, nil
		},
		Sleep: func(_ context.Context, d time.Duration) error {
			f.slept += d
			return nil
		},
		Lookup: lookup,
	}
}

func TestRunReport(t *testing.T) {
	f := &fakeExec{}
	r := Routine{ID: "r", Name: "R", Steps: []Step{
		{Kind: KindAction, Action: "media.next"},
		{Kind: KindDelay, Ms: 1500},
		{Kind: KindTool, Tool: "dnd_set", Args: map[string]any{"enabled": true}},
	}}
	rep := f.executor(nil).Run(context.Background(), r)
	assert.True(t, rep.OK)
	assert.Len(t, rep.Steps, 3)
	assert.Equal(t, StatusOK, rep.Steps[2].Status)
	assert.Equal(t, "Next Track", rep.Steps[0].Label)
	assert.Equal(t, "Wait 1.5s", rep.Steps[1].Label)
	assert.Equal(t, 1500*time.Millisecond, f.slept)
	assert.Equal(t, []string{"dnd_set"}, f.tools)

	// A failure stops the run; the rest is skipped.
	r.Steps = append([]Step{{Kind: KindTool, Tool: "bad_tool"}}, r.Steps...)
	rep = f.executor(nil).Run(context.Background(), r)
	assert.False(t, rep.OK)
	assert.Equal(t, StatusFailed, rep.Steps[0].Status)
	assert.Equal(t, "no such thing", rep.Steps[0].Error)
	assert.Equal(t, StatusSkipped, rep.Steps[3].Status)

	r.ContinueOnError = true
	rep = f.executor(nil).Run(context.Background(), r)
	assert.False(t, rep.OK)
	assert.Equal(t, StatusOK, rep.Steps[3].Status)
}

func TestRunNestedRoutines(t *testing.T) {
	f := &fakeExec{}
	inner := Routine{ID: "inner", Name: "Inner", Steps: []Step{{Kind: KindAction, Action: "media.prev"}}}
	loop := Routine{ID: "loop", Name: "Loop", Steps: []Step{{Kind: KindAction, Action: RoutineAction, Args: map[string]any{"routine": "loop"}}}}
	lookup := func(ref string) (Routine, bool) {
		switch ref {
		case "inner":
			return inner, true
		case "loop":
			return loop, true
		}
		return Routine{}, false
	}
	outer := Routine{ID: "outer", Name: "Outer", Steps: []Step{{Kind: KindAction, Action: RoutineAction, Args: map[string]any{"routine": "inner"}}}}
	rep := f.executor(lookup).Run(context.Background(), outer)
	assert.True(t, rep.OK, "%+v", rep)
	assert.Equal(t, "Inner: 1/1 steps", rep.Steps[0].Output)
	assert.Equal(t, "Run routine inner", rep.Steps[0].Label)

	rep = f.executor(lookup).Run(context.Background(), loop)
	assert.False(t, rep.OK)

	rep = f.executor(lookup).Run(context.Background(), Routine{Name: "x", Steps: []Step{{Kind: KindAction, Action: RoutineAction, Args: map[string]any{"routine": "ghost"}}}})
	assert.Contains(t, rep.Steps[0].Error, "no routine")
}

func TestRunCancelled(t *testing.T) {
	f := &fakeExec{}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	rep := f.executor(nil).Run(ctx, Routine{Name: "x", Steps: []Step{{Kind: KindAction, Action: "media.next"}}})
	assert.False(t, rep.OK)
	assert.Equal(t, StatusSkipped, rep.Steps[0].Status)
}

func call(t *testing.T, s *Service, method string, params any) (map[string]any, error) {
	t.Helper()
	raw, _ := json.Marshal(params)
	res, err := s.methods()[method](raw)
	if err != nil {
		return nil, err
	}
	data, _ := json.Marshal(res)
	var m map[string]any
	assert.NoError(t, json.Unmarshal(data, &m))
	return m, nil
}

func TestServiceCRUDAndRun(t *testing.T) {
	path := filepath.Join(t.TempDir(), FileName)
	f := &fakeExec{fail: "playerctl previous"}
	var notes []string
	s := NewService(Options{Path: path, Exec: f.executor(nil), Notify: func(a, b string) { notes = append(notes, a+": "+b) }})

	m, err := call(t, s, "save", map[string]any{"routine": map[string]any{"name": "Morning", "steps": []any{
		map[string]any{"kind": "action", "action": "media.next"}}}})
	assert.NoError(t, err)
	assert.Equal(t, "morning", m["routine"].(map[string]any)["id"])
	assert.Nil(t, m["previous"])

	// Same name, no id: a second routine with a unique id.
	m, err = call(t, s, "save", map[string]any{"routine": map[string]any{"name": "Morning", "steps": []any{}}})
	assert.NoError(t, err)
	assert.Equal(t, "morning-2", m["routine"].(map[string]any)["id"])

	// Replace keeps the place and returns the previous version.
	m, err = call(t, s, "save", map[string]any{"replace": "morning", "routine": map[string]any{"id": "morning", "name": "Morning!", "steps": []any{
		map[string]any{"kind": "action", "action": "media.prev"}}}})
	assert.NoError(t, err)
	assert.Equal(t, "Morning", m["previous"].(map[string]any)["name"])

	list, _ := Load(path)
	assert.Equal(t, []string{"morning", "morning-2"}, []string{list[0].ID, list[1].ID})

	_, err = call(t, s, "save", map[string]any{"routine": map[string]any{"name": ""}})
	assert.Error(t, err)

	m, err = call(t, s, "get", map[string]any{"id": "Morning!"})
	assert.NoError(t, err)
	assert.Equal(t, "morning", m["routine"].(map[string]any)["id"])

	// A failing run notifies (not when quiet).
	m, err = call(t, s, "run", map[string]any{"id": "morning"})
	assert.NoError(t, err)
	assert.Equal(t, false, m["ok"])
	assert.Len(t, notes, 1)
	assert.Contains(t, notes[0], "Step 1 (Previous Track)")
	_, err = call(t, s, "run", map[string]any{"id": "morning", "quiet": true})
	assert.NoError(t, err)
	assert.Len(t, notes, 1)

	// An unsaved routine (editor test run).
	m, err = call(t, s, "run", map[string]any{"routine": map[string]any{"name": "tmp", "steps": []any{map[string]any{"kind": "delay", "ms": 5}}}})
	assert.NoError(t, err)
	assert.Equal(t, true, m["ok"])
	_, err = call(t, s, "run", map[string]any{"id": "ghost"})
	assert.Error(t, err)

	m, err = call(t, s, "delete", map[string]any{"id": "morning-2"})
	assert.NoError(t, err)
	assert.Equal(t, "morning-2", m["routine"].(map[string]any)["id"])
	_, err = call(t, s, "delete", map[string]any{"id": "morning-2"})
	assert.Error(t, err)

	m, err = call(t, s, "list", nil)
	assert.NoError(t, err)
	assert.Len(t, m["routines"], 1)
}
