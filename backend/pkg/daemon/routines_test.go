package daemon

import (
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/svc/routines"
)

func TestRoutineGate(t *testing.T) {
	path := filepath.Join(t.TempDir(), routines.FileName)
	if err := routines.Save(path, []routines.Routine{
		{ID: "closer", Name: "Closer", Steps: []routines.Step{{Kind: routines.KindTool, Tool: "app_close"}}},
		{ID: "calm", Name: "Calm", Steps: []routines.Step{{Kind: routines.KindTool, Tool: "dnd_set"}}},
	}); err != nil {
		t.Fatal(err)
	}
	g := routineGate{svc: routines.NewService(routines.Options{Path: path})}
	step := func(kind, key, val string) map[string]any { return map[string]any{"kind": kind, key: val} }
	cases := []struct {
		tool string
		in   map[string]any
		want bool
	}{
		{"routine_run", map[string]any{"id": "closer"}, true},
		{"routine_run", map[string]any{"id": "Calm"}, false},
		{"routine_run", map[string]any{"id": "ghost"}, false}, // fails to run anyway
		{"routine_save", map[string]any{"name": "x", "steps": []any{step("tool", "tool", "dnd_set")}}, false},
		{"routine_save", map[string]any{"name": "x", "steps": []any{step("action", "action", "command.run")}}, true},
		{"routine_save", map[string]any{"name": "x", "steps": []any{map[string]any{"kind": "action",
			"action": "utilities.routine", "args": map[string]any{"routine": "closer"}}}}, true},
		{"routine_save", map[string]any{"name": 5}, true}, // unreadable: ask
		{"volume_set", map[string]any{}, false},
	}
	for i, c := range cases {
		if got := g.NeedsConfirm(c.tool, c.in); got != c.want {
			t.Errorf("case %d %s %v: got %v", i, c.tool, c.in, got)
		}
	}
}
