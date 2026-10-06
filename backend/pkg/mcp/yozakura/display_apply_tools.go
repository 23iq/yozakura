package yozakura

import (
	"context"
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/mcp"
	yipc "yozakura/backend/pkg/yozd/ipc"
)

// Monitor layout tools (resolution, refresh rate, scale, rotation). A change
// always goes through the daemon's confirm session: it reverts by itself
// after revertIn seconds unless it is kept ("keep": true, or displays_confirm).

func displayLayoutTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("displays_list", "List monitors",
			`The connected monitors with connector name (usable as "name" in displays_apply), current mode, position, scale, rotation, VRR and every supported mode.`,
			noArgs, toolOpts{readOnly: true}, d.displaysList),
		define("displays_apply", "Change monitor settings",
			`Change resolution/refresh rate ("mode": "2560x1440@165" or "preferred"), "scale", "transform" (0-7, 1=90, 2=180, 3=270), "vrr" (0 off, 1 on, 2 fullscreen), "enabled", "x"/"y" of one or more monitors (see displays_list). Applied live, then REVERTED automatically after revertIn seconds (15) unless "keep": true is given or displays_confirm is called with the returned session, so a bad mode never sticks. Only ask for keep after the user confirmed the picture is fine.`,
			`{"type":"object","properties":{"outputs":{"type":"array","minItems":1,"items":{"type":"object","properties":{"name":{"type":"string"},"mode":{"type":"string"},"scale":{"type":"number","minimum":0.25,"maximum":4},"transform":{"type":"integer","minimum":0,"maximum":7},"vrr":{"type":"integer","minimum":0,"maximum":2},"enabled":{"type":"boolean"},"x":{"type":"integer"},"y":{"type":"integer"}},"required":["name"],"additionalProperties":false}},"keep":{"type":"boolean","default":false}},"required":["outputs"],"additionalProperties":false}`,
			toolOpts{}, d.displaysApply),
		define("displays_confirm", "Keep or revert monitor change",
			`Answer a pending displays_apply session: "keep": true saves the layout as it is now, false reverts at once. After revertIn seconds without an answer the change is reverted automatically.`,
			`{"type":"object","properties":{"session":{"type":"string"},"keep":{"type":"boolean"}},"required":["session","keep"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.displaysConfirm),
	}
}

func (d Deps) displaysList(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	outs, err := ListOutputs(d.callerOrNil())
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"displays": outs}), nil
}

type displayChangeArg struct {
	Name      string
	Mode      string
	Scale     *float64
	Transform *int
	Vrr       *int
	Enabled   *bool
	X, Y      *int
}

func (d Deps) displaysApply(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Outputs []displayChangeArg
		Keep    bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if len(a.Outputs) == 0 {
		return nil, fmt.Errorf("outputs is required")
	}
	outs, err := ListOutputs(d.callerOrNil())
	if err != nil {
		return nil, err
	}
	var cfgs, before []yipc.OutputConfig
	for _, ch := range a.Outputs {
		o, err := FindOutput(outs, ch.Name)
		if err != nil {
			return nil, err
		}
		c, err := BuildOutputConfig(o, OutputChange{Name: o.Name, Mode: ch.Mode, Scale: ch.Scale, Transform: ch.Transform, VRR: ch.Vrr, Enabled: ch.Enabled, X: ch.X, Y: ch.Y})
		if err != nil {
			return nil, err
		}
		cfgs = append(cfgs, c)
		before = append(before, OutputConfigOf(o))
	}
	sess, err := StartDisplayApply(d.callerOrNil(), cfgs)
	if err != nil {
		return nil, err
	}
	out := map[string]any{"session": sess.Session, "applied": cfgs, "was": before}
	if !a.Keep {
		out["state"] = "pending"
		out["revertIn"] = sess.RevertIn
		out["note"] = "reverts automatically unless displays_confirm keep=true is called"
		return mcp.JSONResult(out), nil
	}
	_, store, err := d.catalog()
	if err != nil {
		store = nil // saving is best effort; the change is live and kept
	}
	if err := KeepDisplays(d.callerOrNil(), store, sess.Session, cfgs, outs); err != nil {
		return nil, err
	}
	out["state"] = "kept"
	return mcp.JSONResult(out), nil
}

func (d Deps) displaysConfirm(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Session string
		Keep    bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Session == "" {
		return nil, fmt.Errorf("session is required")
	}
	if !a.Keep {
		if err := RevertDisplays(d.callerOrNil(), a.Session); err != nil {
			return nil, err
		}
		return mcp.JSONResult(map[string]any{"state": "reverted"}), nil
	}
	// The session knows what it applied; the connected outputs now show it.
	outs, err := ListOutputs(d.callerOrNil())
	if err != nil {
		return nil, err
	}
	cfgs := make([]yipc.OutputConfig, 0, len(outs))
	for _, o := range outs {
		cfgs = append(cfgs, OutputConfigOf(o))
	}
	_, store, cerr := d.catalog()
	if cerr != nil {
		store = nil
	}
	if err := KeepDisplays(d.callerOrNil(), store, a.Session, cfgs, outs); err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"state": "kept"}), nil
}
