package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/presets"
)

// Preset tools work on the preset directories directly (package presets),
// exactly like `yozakura preset`; the shell hot-reloads applied files.

func (d Deps) presets() (*presets.Manager, error) {
	cat, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	official := ""
	if d.ShellSource != "" {
		official = filepath.Join(d.ShellSource, "assets", "presets")
	}
	return &presets.Manager{Cat: cat, Store: store, UserDir: d.PresetsDir, OfficialDir: official,
		WallpaperFile: d.WallpapersFile, StateDir: d.StateDir}, nil
}

func presetTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("presets_list", "List presets",
			`List the shell's theme/layout presets: name, official or user-made, author, the config domains each one sets, and which one is active. Use a name with preset_apply or preset_diff.`,
			noArgs, toolOpts{readOnly: true}, d.presetsList),
		define("preset_apply", "Apply preset",
			`Apply a preset by name (case-insensitive): its config domain files replace the live ones (bar, theme, notch, dock, compositor, ...) and the shell hot-reloads them. Call presets_list first; consider preset_save "Backup" before, so the user can go back. Values the catalog rejects are reported as warnings.`,
			`{"type":"object","properties":{"name":{"type":"string","description":"Preset name as returned by presets_list."}},"required":["name"],"additionalProperties":false}`,
			toolOpts{destructive: true, idempotent: true}, d.presetApply),
		define("preset_save", "Save preset",
			`Save the live config as a user preset (copies the config domain files; private domains and machine-local keys such as secrets, commands and endpoints are never included). Built-in names are refused; an existing user preset is only replaced with overwrite true.`,
			`{"type":"object","properties":{"name":{"type":"string","description":"Preset name."},"domains":{"type":"array","items":{"type":"string"},"description":"Only these domains (default: all that exist)."},"overwrite":{"type":"boolean","description":"Replace an existing user preset of that name."}},"required":["name"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.presetSave),
		define("preset_diff", "Compare presets",
			`List the config keys that differ between two presets, as the shell would run them (missing keys = defaults). Either side may be "current" (the live config). Use it to explain what applying a preset would change: {"a":"current","b":"Neon Tokyo"}.`,
			`{"type":"object","properties":{"a":{"type":"string","description":"Preset name or \"current\"."},"b":{"type":"string","description":"Preset name or \"current\"."}},"required":["a","b"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.presetDiff),
		define("preset_show", "Inspect preset",
			`Describe a preset aspect by aspect (layout, colors, windows, desktop, lockscreen): the keys it sets differently from the defaults (or from "against", another preset), with the settings page of each key, and which other presets share each aspect exactly. Use it to explain a preset or to find where to edit something.`,
			`{"type":"object","properties":{"name":{"type":"string","description":"Preset name or \"current\"."},"against":{"type":"string","description":"Reference: \"defaults\" (default) or a preset name."}},"required":["name"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.presetShow),
		define("preset_mix", "Mix preset",
			`Create a user preset by taking each aspect from a source: sources maps an aspect (layout = bar/notch/dock/overview/workspaces, colors = theme + glass + matugen scheme, windows = compositor + performance + motion, desktop, lockscreen) to a preset name, "current" or "defaults". Omitted aspects are left out. Apply it afterwards with preset_apply.`,
			`{"type":"object","properties":{"name":{"type":"string","description":"New preset name."},"sources":{"type":"object","additionalProperties":{"type":"string"},"description":"aspect -> preset name, \"current\" or \"defaults\"."},"description":{"type":"string"},"overwrite":{"type":"boolean"}},"required":["name","sources"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.presetMix),
		define("preset_duplicate", "Duplicate preset",
			`Copy any preset (built-in presets are read-only, so duplicate one to customize it) to a new user preset. newName defaults to "<name> copy".`,
			`{"type":"object","properties":{"name":{"type":"string","description":"Preset to copy."},"newName":{"type":"string"}},"required":["name"],"additionalProperties":false}`,
			toolOpts{}, d.presetDuplicate),
		define("preset_rename", "Rename preset",
			`Rename a user preset (built-in presets cannot be renamed). The active-preset marker follows the rename.`,
			`{"type":"object","properties":{"name":{"type":"string"},"newName":{"type":"string"}},"required":["name","newName"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.presetRename),
		define("preset_delete", "Delete preset",
			`Move a user preset to the trash (restorable for 7 days with `+"`yozakura preset restore <id>`"+`). Built-in presets cannot be deleted.`,
			`{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}`,
			toolOpts{destructive: true}, d.presetDelete),
	}
}

func (d Deps) presetShow(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name, Against string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	ins, err := m.Inspect(a.Name, a.Against)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(ins), nil
}

func (d Deps) presetMix(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Name        string
		Sources     map[string]string
		Description string
		Overwrite   bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if len(a.Sources) == 0 {
		return nil, fmt.Errorf("sources is required")
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, err := m.Mix(a.Name, a.Sources, a.Description, a.Overwrite)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"created": p.Name, "domains": p.Domains, "description": p.Description}), nil
}

func (d Deps) presetDuplicate(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name, NewName string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, err := m.Duplicate(a.Name, a.NewName)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"created": p.Name, "path": p.Path}), nil
}

func (d Deps) presetRename(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name, NewName string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, err := m.Rename(a.Name, a.NewName)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"renamed": p.Name}), nil
}

func (d Deps) presetDelete(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	t, err := m.Delete(a.Name)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"deleted": t.Name, "restore": t.ID}), nil
}

func (d Deps) presetsList(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	list := m.List()
	if list == nil {
		list = []presets.Preset{}
	}
	return mcp.JSONResult(map[string]any{"presets": list, "active": m.Active()}), nil
}

func (d Deps) presetApply(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Name == "" {
		return nil, fmt.Errorf("name is required")
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, problems, err := m.Apply(a.Name)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"applied": p.Name, "domains": p.Domains, "warnings": problems}), nil
}

func (d Deps) presetSave(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Name      string
		Domains   []string
		Overwrite bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, err := m.Save(a.Name, a.Domains, a.Overwrite)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"saved": p.Name, "domains": p.Domains, "path": p.Path}), nil
}

func (d Deps) presetDiff(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ A, B string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.A == "" || a.B == "" {
		return nil, fmt.Errorf("a and b are required")
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	diffs, err := m.Compare(a.A, a.B)
	if err != nil {
		return nil, err
	}
	if diffs == nil {
		diffs = []presets.Diff{}
	}
	return mcp.JSONResult(map[string]any{"a": a.A, "b": a.B, "count": len(diffs), "differences": diffs}), nil
}
