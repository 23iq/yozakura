package yozakura

import (
	"context"
	"encoding/json"
	"path/filepath"

	"yozakura/backend/pkg/binds"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/specials"
	"yozakura/backend/pkg/yozd/ipc"
)

// Bind advisor (backend/pkg/binds): find what a key can run, see every bind
// with its source, check and suggest combos, and edit binds.json with undo.
// The compositor's own config is read, never written.

const comboProp = `"combo":{"type":"string","description":"Key combination, e.g. \"SUPER+SHIFT+S\", \"super + .\", \"SUPER\" (lone Super). Modifiers: SUPER (MOD4/WIN), CTRL, ALT, SHIFT."}`

func bindTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("binds_search", "Search bindable actions",
			`Find what a keybind could run, from a natural request in any language ("switch keyboard layout", "громкость", "open Firefox"): shell and compositor actions of the bind catalog, installed apps, launcher commands, routines, and workarounds (compositor features through yozd, system commands) when the catalog has no action. Each result has "action" ({id, args}) ready for binds_set, its "fields" (arguments to fill) and "bound" (combos already running it). Read only.`,
			`{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":50,"description":"Default 8."}},"required":["query"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.bindsSearch),
		define("binds_list", "List keybinds",
			`List keybinds with their source: "shell-core" (the shell's own binds), "shell-user" (custom binds in binds.json) and "compositor" (the compositor's own config, read through yozd; read only here). Filter by source and/or text (matches combo, label, name, action id). Disabled shell binds are listed with enabled=false.`,
			`{"type":"object","properties":{"source":{"type":"string","enum":["shell-core","shell-user","compositor"]},"filter":{"type":"string"}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.bindsList),
		define("binds_check", "Check key combination",
			`Tell whether a key combination is free: lists every enabled bind using it (any source) and whether it is reserved by convention (CTRL+ALT+DEL, SUPER+1..0, ...). Read only.`,
			`{"type":"object","properties":{`+comboProp+`},"required":["combo"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.bindsCheck),
		define("binds_suggest", "Suggest free key combinations",
			`Suggest free, ergonomic combos for an action (catalog id from binds_search, or a description): SUPER + a letter of its label first, then SUPER+SHIFT / SUPER+ALT / SUPER+CTRL, skipping taken and reserved combos. Also says which combos already run it. Read only.`,
			`{"type":"object","properties":{"action":{"type":"string","description":"Action id (e.g. window.toggle-float) or what it should do."},"count":{"type":"integer","minimum":1,"maximum":20,"description":"Default 5."}},"required":["action"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.bindsSuggest),
		define("binds_set", "Bind a key combination",
			`Bind a combo to an action in binds.json (the shell's keybinds; it applies live). ALWAYS confirm with the user first: show the combo and what it will do, and any conflict. Never edits the compositor's own config: a combo used there is refused. A combo used by another shell bind is refused unless replace=true (that bind is unbound; say so). For a shell core action (e.g. the launcher) the core bind is moved to the new combo unless additional=true. action is a catalog id from binds_search (apps: "apps.launch" with args.app; any command: "command.run" with args.command). The result has "undo" ({tool, args}): offer it to the user.`,
			`{"type":"object","properties":{`+comboProp+`,"action":{"type":"string"},"args":{"type":"object","description":"Action arguments (binds_search fields)."},"name":{"type":"string","description":"Name of a new custom bind (default: the action label)."},"replace":{"type":"boolean"},"additional":{"type":"boolean"}},"required":["combo","action"],"additionalProperties":false}`,
			toolOpts{}, d.bindsSet),
		define("binds_remove", "Unbind a key combination",
			`Unbind a combo in binds.json: a shell core bind is switched off, a custom bind loses that key (or is removed). ALWAYS confirm with the user first. action limits it to binds running that action id. Compositor-config binds are never touched. The result has "undo" ({tool, args}).`,
			`{"type":"object","properties":{`+comboProp+`,"action":{"type":"string"}},"required":["combo"],"additionalProperties":false}`,
			toolOpts{destructive: true}, d.bindsRemove),
		define("binds_undo", "Undo a keybind change",
			`Revert a binds_set / binds_remove / binds_undo from the token in its "undo". Refused when binds.json changed in a way the undo cannot restore. The result carries a token to redo.`,
			`{"type":"object","properties":{"token":{"type":"string"}},"required":["token"],"additionalProperties":false}`,
			toolOpts{}, d.bindsUndo),
	}
}

func (d Deps) bindAdvisor() (*binds.Advisor, error) {
	cat, err := binds.LoadCatalog(d.ShellSource)
	if err != nil {
		return nil, err
	}
	a := &binds.Advisor{
		Catalog:        cat,
		File:           d.BindsFile,
		CompositorName: binds.DetectCompositor(),
		Apps:           binds.AppsIn(d.appDirs()),
		Commands:       binds.CommandsIn(d.ShellSource),
		Routines:       binds.RoutinesFrom(d.RoutinesFile),
		Specials: func() ([]specials.Special, error) {
			_, list, err := d.loadSpecials()
			return list, err
		},
	}
	if d.StateDir != "" {
		a.LockFile = filepath.Join(d.StateDir, "binds.lock")
	}
	if d.Run != nil && d.Run.LookPath(brand.Daemon) {
		a.Compositor = func() ([]ipc.Bind, error) {
			out, err := d.Run.Run(context.Background(), nil, brand.Daemon, "config", "list-binds")
			if err != nil {
				return nil, err
			}
			return binds.ParseDaemonBinds(out)
		}
	}
	return a, nil
}

func (d Deps) bindsSearch(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Query string
		Limit int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Limit <= 0 {
		a.Limit = 8
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	res, err := adv.Search(a.Query, a.Limit)
	if err != nil {
		return nil, err
	}
	out := map[string]any{"results": res}
	if len(res) == 0 || res[0].Score < 0.6 {
		out["hints"] = binds.FallbackHints()
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) bindsList(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Source, Filter string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	l, err := adv.List()
	if err != nil {
		return nil, err
	}
	l.Binds = binds.Filter(l.Binds, a.Source, a.Filter)
	return mcp.JSONResult(l), nil
}

func (d Deps) bindsCheck(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Combo string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	r, err := adv.Check(a.Combo)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(r), nil
}

func (d Deps) bindsSuggest(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Action string
		Count  int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	r, err := adv.Suggest(a.Action, a.Count)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(r), nil
}

func (d Deps) bindsSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var req binds.SetRequest
	if err := decode(args, &req); err != nil {
		return nil, err
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	r, err := adv.Set(req)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(r), nil
}

func (d Deps) bindsRemove(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Combo, Action string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	r, err := adv.Remove(a.Combo, a.Action)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(r), nil
}

func (d Deps) bindsUndo(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Token string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	adv, err := d.bindAdvisor()
	if err != nil {
		return nil, err
	}
	r, err := adv.Undo(a.Token)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(r), nil
}
