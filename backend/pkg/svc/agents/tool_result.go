package agents

import (
	"encoding/json"
	"regexp"
	"strings"
)

// yozakuraToolName matches how agents name our own tools:
// "mcp__yozakura__timer_start" (Claude Code, Codex), "yozakura.timer_start"
// or "yozakura__timer_start" (OpenCode). Same as ToolMedia.isYozakuraTool.
var yozakuraToolName = regexp.MustCompile(`^(mcp__)?` + regexp.QuoteMeta(YozakuraMCPName) + `(__|[.:/])`)

// toolResultEvent is a tool_result event. The output is truncated for the
// timeline; the undo descriptor a Yozakura tool returns ({"undo": {tool,
// args, label}} in its JSON) is taken from the whole output first, so a
// long result keeps its Undo.
func toolResultEvent(id, tool, output string, isErr bool) Event {
	ev := Event{Kind: KindToolResult, ID: id, Tool: tool, Output: truncate(output), IsError: isErr}
	if !isErr && yozakuraToolName.MatchString(tool) {
		ev.Undo = undoOf(output)
	}
	return ev
}

// undoOf returns the "undo" object of a JSON tool result, or nil.
func undoOf(output string) map[string]any {
	t := strings.TrimSpace(output)
	if !strings.HasPrefix(t, "{") || !strings.Contains(t, `"undo"`) {
		return nil
	}
	var v struct {
		Undo map[string]any `json:"undo"`
	}
	if json.Unmarshal([]byte(t), &v) != nil {
		return nil
	}
	if name, _ := v.Undo["tool"].(string); name == "" {
		return nil
	}
	return v.Undo
}
