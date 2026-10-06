package routines

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestConfirmSteps(t *testing.T) {
	list := []Routine{
		{ID: "closer", Steps: []Step{{Kind: KindTool, Tool: "app_close"}}},
		{ID: "loop", Steps: []Step{{Kind: KindAction, Action: RoutineAction, Args: map[string]any{"routine": "loop"}}}},
	}
	lookup := func(ref string) (Routine, bool) {
		if i := Find(list, ref); i >= 0 {
			return list[i], true
		}
		return Routine{}, false
	}
	assert.Len(t, ConfirmSteps(Routine{Steps: []Step{{Kind: KindTool, Tool: "dnd_set"}, {Kind: KindAction, Action: "media.next"},
		{Kind: KindDelay, Ms: 5}}}, lookup), 0)
	assert.Equal(t, []string{"binds_set", "command.run", "window.close"}, ConfirmSteps(Routine{Steps: []Step{
		{Kind: KindTool, Tool: "binds_set"}, {Kind: KindAction, Action: "command.run", Args: map[string]any{"command": "rm -rf ~"}},
		{Kind: KindAction, Action: "window.close"}}}, lookup))
	// Nested routines count, unknown ones too; cycles end.
	nested := Routine{Steps: []Step{{Kind: KindAction, Action: RoutineAction, Args: map[string]any{"routine": "closer"}}}}
	assert.Equal(t, []string{"app_close"}, ConfirmSteps(nested, lookup))
	ghost := Routine{Steps: []Step{{Kind: KindAction, Action: RoutineAction, Args: map[string]any{"routine": "ghost"}}}}
	assert.Equal(t, []string{"routine ghost"}, ConfirmSteps(ghost, lookup))
	assert.Len(t, ConfirmSteps(list[1], lookup), 0)
}

func TestAgentRunNeedsGrant(t *testing.T) {
	path := filepath.Join(t.TempDir(), FileName)
	f := &fakeExec{}
	s := NewService(Options{Path: path, Exec: f.executor(nil)})
	now := time.Unix(1000, 0)
	s.grants.now = func() time.Time { return now }
	for _, r := range []map[string]any{
		{"name": "Close", "steps": []any{map[string]any{"kind": "tool", "tool": "app_close", "args": map[string]any{"app": "x"}}}},
		{"name": "Calm", "steps": []any{map[string]any{"kind": "tool", "tool": "dnd_set"}}},
	} {
		_, err := call(t, s, "save", map[string]any{"routine": r})
		assert.NoError(t, err)
	}
	assert.Equal(t, []string{"app_close"}, s.ConfirmFor("close"))
	assert.Len(t, s.ConfirmFor("calm"), 0)

	// An AI run of a confirm-required routine needs the user's grant.
	_, err := call(t, s, "run", map[string]any{"id": "close", "agent": true})
	assert.ErrorContains(t, err, "need the user's confirmation (app_close)")
	assert.Len(t, f.tools, 0)
	// Unsaved routines from an AI never run confirm steps.
	_, err = call(t, s, "run", map[string]any{"agent": true, "routine": map[string]any{"name": "x", "steps": []any{
		map[string]any{"kind": "tool", "tool": "binds_set"}}}})
	assert.Error(t, err)
	// Safe routines and user runs need nothing.
	_, err = call(t, s, "run", map[string]any{"id": "calm", "agent": true})
	assert.NoError(t, err)
	_, err = call(t, s, "run", map[string]any{"id": "close"})
	assert.NoError(t, err)

	// A grant allows one run, within its lifetime.
	_, err = call(t, s, "grant", map[string]any{"id": "Close"})
	assert.NoError(t, err)
	_, err = call(t, s, "run", map[string]any{"id": "close", "agent": true})
	assert.NoError(t, err)
	_, err = call(t, s, "run", map[string]any{"id": "close", "agent": true})
	assert.Error(t, err)
	s.Grant("close")
	now = now.Add(grantTTL + time.Second)
	_, err = call(t, s, "run", map[string]any{"id": "close", "agent": true})
	assert.Error(t, err)
	_, err = call(t, s, "grant", map[string]any{"id": "ghost"})
	assert.Error(t, err)
}
