package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/presets"
)

// Sharing presets (single-file bundles) and the parts sets are built from.

func presetShareTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("preset_export", "Export preset",
			`Write a preset (or "current", the live config) as a single-file JSON bundle to share it. A set built from a layout, style and palette is exported composed (self-contained). file defaults to ~/<name>.`+presets.BundleFormat+`.json; machine-local keys are never included.`,
			`{"type":"object","properties":{"name":{"type":"string","description":"Preset name or \"current\"."},"file":{"type":"string","description":"Output path (absolute or ~/...)."}},"required":["name"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.presetExport),
		define("preset_import", "Import preset",
			`Install a preset bundle file (from preset_export) as a user preset. It is validated against the settings catalog first: an unknown domain or an invalid value rejects the whole import and nothing changes. name overrides the bundle's name; an existing user preset is replaced only with force true. Apply it afterwards with preset_apply.`,
			`{"type":"object","properties":{"file":{"type":"string","description":"Bundle path (absolute or ~/...)."},"name":{"type":"string"},"force":{"type":"boolean"}},"required":["file"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.presetImport),
		define("preset_parts", "List preset parts",
			`List the layouts (bar/notch/dock/layout/overview), styles (theme, compositor, lockscreen, desktop, workspaces) and palettes (colors, light/dark) that sets are composed from, and the current one of each kind. Apply one alone with preset_apply_part.`,
			noArgs, toolOpts{readOnly: true}, d.presetParts),
		define("preset_apply_part", "Apply preset part",
			`Apply only a layout, a style or a palette: its keys are merged into the live config and every other key stays (e.g. keep the layout, change the colors with {"kind":"palette","name":"Ice"}). Call preset_parts for the names.`,
			`{"type":"object","properties":{"kind":{"type":"string","enum":["layout","style","palette"]},"name":{"type":"string"}},"required":["kind","name"],"additionalProperties":false}`,
			toolOpts{destructive: true, idempotent: true}, d.presetApplyPart),
	}
}

func (d Deps) presetExport(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name, File string }
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
	file := expandHome(a.File)
	if file == "" {
		file = expandHome("~/" + a.Name + "." + presets.BundleFormat + ".json")
	}
	b, err := m.Export(a.Name, file)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"exported": b.Name, "file": file, "domains": b.DomainNames()}), nil
}

func (d Deps) presetImport(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		File, Name string
		Force      bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.File == "" {
		return nil, fmt.Errorf("file is required")
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	file := expandHome(a.File)
	problems, err := m.CheckBundle(file)
	if err != nil {
		return nil, err
	}
	if len(problems) > 0 {
		msgs := make([]string, len(problems))
		for i, p := range problems {
			msgs[i] = p.Key + ": " + p.Message
		}
		return nil, fmt.Errorf("the bundle does not validate, nothing was imported: %s", strings.Join(msgs, "; "))
	}
	p, _, err := m.Import(file, a.Name, a.Force)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"imported": p.Name, "domains": p.Domains, "path": p.Path}), nil
}

func (d Deps) presetParts(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	r := presets.PartsReport{Current: m.CurrentParts()}
	lists := map[string]*[]presets.Part{presets.PartLayout: &r.Layouts, presets.PartStyle: &r.Styles, presets.PartPalette: &r.Palettes}
	for _, kind := range presets.PartKinds {
		if *lists[kind], err = m.Parts(kind); err != nil {
			return nil, err
		}
	}
	return mcp.JSONResult(r), nil
}

func (d Deps) presetApplyPart(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Kind, Name string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	m, err := d.presets()
	if err != nil {
		return nil, err
	}
	p, problems, err := m.ApplyPart(a.Kind, a.Name)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"applied": p.Name, "kind": p.Kind, "domains": p.Domains, "warnings": problems}), nil
}
