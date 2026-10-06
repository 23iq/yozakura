package yozakura

import (
	"context"
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/mcp"
)

// Focus mode lives in the shell (modules/services/FocusMode.qml: Do Not
// Disturb + a timer + hidden badges, a summary of missed notifications at
// the end); these tools drive it through `ui.run` commands handled by
// UtilityCommands.qml.

func focusTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("focus_start", "Start focus mode",
			`Start focus mode: Do Not Disturb on, a countdown in the notch, notification badges hidden; when it ends DND is restored and the user sees what they missed. "minutes" defaults to the user's setting (system.focus.minutes). Starting again restarts it with the new length.`,
			`{"type":"object","properties":{"minutes":{"type":"integer","minimum":1,"maximum":480}},"additionalProperties":false}`,
			toolOpts{}, d.focusStart),
		define("focus_stop", "Stop focus mode",
			`End focus mode now (Do Not Disturb goes back to what it was, the missed-notifications summary is shown).`,
			noArgs, toolOpts{idempotent: true}, d.focusStop),
	}
}

func (d Deps) focusStart(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Minutes int }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	cmd := "focus:0"
	if a.Minutes > 0 {
		cmd = fmt.Sprintf("focus:%d", a.Minutes)
	}
	if err := d.uiRun(cmd); err != nil {
		return nil, err
	}
	out := map[string]any{"focus": "started", "undo": undo("focus_stop", map[string]any{})}
	if a.Minutes > 0 {
		out["minutes"] = a.Minutes
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) focusStop(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	if err := d.uiRun("focus-stop"); err != nil {
		return nil, err
	}
	return mcp.TextResult("Focus mode stopped"), nil
}
