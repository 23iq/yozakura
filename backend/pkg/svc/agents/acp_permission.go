package agents

import (
	"encoding/json"
	"strings"
)

// ACP session/request_permission handling.

func (c *acpConn) onRequest(id json.RawMessage, method string, params json.RawMessage) {
	if method != "session/request_permission" {
		_ = c.rpc.ReplyError(id, -32601, "method not supported by Yozakura: "+method)
		return
	}
	var p struct {
		ToolCall acpToolCall `json:"toolCall"`
		Options  []struct {
			OptionID string `json:"optionId"`
			Kind     string `json:"kind"`
		} `json:"options"`
	}
	_ = json.Unmarshal(params, &p)
	// The request carries the freshest view of the call (diffs included).
	c.onToolCall(p.ToolCall)
	t := c.tools[p.ToolCall.ToolCallID]
	tool := c.toolName(t)
	cat := Classify(tool, t.input)
	pick := func(kinds ...string) string {
		for _, k := range kinds {
			for _, o := range p.Options {
				if o.Kind == k {
					return o.OptionID
				}
			}
		}
		return ""
	}
	reqID := p.ToolCall.ToolCallID
	if reqID == "" {
		reqID = "acp-" + strings.Trim(string(id), `"`)
	}
	c.sink.Permission(PermissionRequest{ID: reqID, Tool: tool, Title: c.title(t), Category: cat, Input: t.input,
		RuleKey: ruleKey(tool, cat, t.input)}, func(d string) {
		var opt string
		switch d {
		case DecisionAllow:
			opt = pick("allow_once", "allow_always")
		case DecisionAllowSession:
			opt = pick("allow_always", "allow_once")
		default:
			opt = pick("reject_once", "reject_always")
		}
		if opt == "" {
			_ = c.rpc.Reply(id, map[string]any{"outcome": map[string]any{"outcome": "cancelled"}})
			return
		}
		_ = c.rpc.Reply(id, map[string]any{"outcome": map[string]any{"outcome": "selected", "optionId": opt}})
	})
}
