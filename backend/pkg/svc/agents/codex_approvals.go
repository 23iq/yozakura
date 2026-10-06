package agents

import (
	"encoding/json"
	"strings"
)

// Codex approvals: server->client requests answered with a decision.

func (c *codexConn) onRequest(id json.RawMessage, method string, params json.RawMessage) {
	if c.opts.Mode == "oneshot" {
		switch method {
		case "item/permissions/requestApproval":
			_ = c.rpc.Reply(id, map[string]any{"permissions": map[string]any{}, "scope": "turn"})
		case "execCommandApproval", "applyPatchApproval":
			_ = c.rpc.Reply(id, map[string]any{"decision": "denied"})
		default:
			_ = c.rpc.Reply(id, map[string]any{"decision": "decline"})
		}
		return
	}
	var p struct {
		ItemID         string           `json:"itemId"`
		Command        string           `json:"command"`
		Cwd            string           `json:"cwd"`
		CommandActions []map[string]any `json:"commandActions"`
		Reason         string           `json:"reason"`
		Permissions    json.RawMessage  `json:"permissions"`
	}
	_ = json.Unmarshal(params, &p)
	reqID := "codex-" + strings.Trim(string(id), `"`)
	if p.ItemID != "" {
		reqID = p.ItemID
	}
	switch method {
	case "item/commandExecution/requestApproval", "execCommandApproval":
		cmd := unwrapShell(p.Command)
		in := map[string]any{"command": cmd, "cwd": p.Cwd}
		if p.Reason != "" {
			in["reason"] = p.Reason
		}
		cat := commandCategory(p.Command, p.CommandActions)
		legacy := method == "execCommandApproval"
		c.sink.Permission(PermissionRequest{ID: reqID, Tool: "shell", Title: "$ " + oneLine(cmd, 120), Category: cat, Input: in,
			RuleKey: ruleKey("shell", CatExec, in)}, func(d string) { _ = c.rpc.Reply(id, map[string]any{"decision": codexDecision(d, legacy)}) })
	case "item/fileChange/requestApproval", "applyPatchApproval":
		in := map[string]any{}
		if p.Reason != "" {
			in["reason"] = p.Reason
		}
		legacy := method == "applyPatchApproval"
		c.sink.Permission(PermissionRequest{ID: reqID, Tool: "apply_patch", Title: "Apply file changes", Category: CatWrite, Input: in,
			RuleKey: "apply_patch"}, func(d string) { _ = c.rpc.Reply(id, map[string]any{"decision": codexDecision(d, legacy)}) })
	case "item/permissions/requestApproval":
		var perms any
		_ = json.Unmarshal(p.Permissions, &perms)
		in := map[string]any{"permissions": perms, "reason": p.Reason}
		c.sink.Permission(PermissionRequest{ID: reqID, Tool: "permissions", Title: "Extra permissions: " + oneLine(p.Reason, 80), Category: CatSandbox,
			Input: in, RuleKey: "permissions"}, func(d string) {
			if d == DecisionDeny {
				_ = c.rpc.Reply(id, map[string]any{"permissions": map[string]any{}, "scope": "turn"})
				return
			}
			scope := "turn"
			if d == DecisionAllowSession {
				scope = "session"
			}
			_ = c.rpc.Reply(id, map[string]any{"permissions": perms, "scope": scope})
		})
	default:
		_ = c.rpc.ReplyError(id, -32601, "unsupported by Yozakura: "+method)
	}
}

func codexDecision(d string, legacy bool) string {
	if legacy {
		switch d {
		case DecisionAllow:
			return "approved"
		case DecisionAllowSession:
			return "approved_for_session"
		}
		return "denied"
	}
	switch d {
	case DecisionAllow:
		return "accept"
	case DecisionAllowSession:
		return "acceptForSession"
	}
	return "decline"
}
