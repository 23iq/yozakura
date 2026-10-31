package yozakura

import (
	"context"
	"encoding/json"

	"yozakura/backend/pkg/mcp"
)

// The active preset against the live config: what changed since it was
// applied, and saving those changes into it.

func presetCurrentTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("preset_status", "Active preset status",
			`The active preset (name, official or the user's own) and the settings whose live value differs from it (key, live value a, preset value b). Use it before preset_save_current to tell the user what would be stored.`,
			noArgs, toolOpts{readOnly: true}, d.presetStatus),
		define("preset_save_current", "Save into active preset",
			`Store the live settings into the active preset ("Save to current preset"). A built-in preset is read-only: pass as with a new name to save the live settings as a new user preset that becomes the active one. Machine-specific domains (keyboard, displays, system, ...) and secrets are never stored. Returns an undo id (preset_undo_save).`,
			`{"type":"object","properties":{"as":{"type":"string","description":"Save as a new user preset with this name (required for built-in presets)."}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.presetSaveCurrent),
		define("preset_undo_save", "Undo preset save",
			`Put back the version of a user preset that preset_save_current replaced, by the undo id it returned.`,
			`{"type":"object","properties":{"id":{"type":"string"}},"required":["id"],"additionalProperties":false}`,
			toolOpts{destructive: true}, d.presetUndoSave),
	}
}

func (d Deps) presetStatus(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	st, err := m.Status()
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(st), nil
}

func (d Deps) presetSaveCurrent(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ As string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	if a.As != "" {
		p, err := m.SaveCurrentAs(a.As)
		if err != nil {
			return nil, err
		}
		return mcp.JSONResult(map[string]any{"saved": p.Name, "active": true}), nil
	}
	p, undo, err := m.SaveCurrent()
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"saved": p.Name, "undo": undo}), nil
}

func (d Deps) presetUndoSave(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, err := m.UndoSave(a.ID)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"restored": p.Name}), nil
}
