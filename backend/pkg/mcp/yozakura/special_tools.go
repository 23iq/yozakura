package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/specials"
)

// Special workspaces (Hyprland scratchpads, config specials.workspaces):
// list, open, add, update, remove, add an app. Same model and validation as
// `yozakura special` (backend/pkg/specials).

const specialRef = `"name":{"type":"string","description":"The special's id, display name or Hyprland name (from specials_list)."}`

const specialFields = `"icon":{"type":"string","description":"Icons glyph name, e.g. chatDots, code, musicNotes, notePencil, stack."},` +
	`"accent":{"type":"string","enum":["primary","secondary","tertiary","error","red","yellow","green","cyan","blue","magenta"],"description":"Palette role."},` +
	`"toggle":{"type":"string","description":"Toggle bind, e.g. \"SUPER+S\" (\"\" clears)."},` +
	`"send":{"type":"string","description":"Send-active-window bind, e.g. \"SUPER+ALT+S\" (\"\" clears)."},` +
	`"preload":{"type":"boolean","description":"Start its apps hidden at login."}`

func specialTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("specials_list", "List special workspaces",
			`List the special workspaces (Hyprland scratchpads): id, name, Hyprland workspace (special:<name>), icon, accent, toggle and send binds, preload, apps (class match, launch command, ifRunning, rule) and how many windows each holds now. They are global like the keybinds: presets never change them.`,
			noArgs, toolOpts{readOnly: true}, d.specialsList),
		define("special_open", "Open special workspace",
			`Open (or close, when it is open) a special workspace. With the shell running its apps are launched into it first (no double launch); otherwise it is a plain compositor toggle.`,
			`{"type":"object","properties":{`+specialRef+`},"required":["name"],"additionalProperties":false}`,
			toolOpts{}, d.specialOpen),
		define("special_add", "Add special workspace",
			`Create a special workspace. The Hyprland name is derived safely from name. apps lists installed desktop ids (e.g. "org.telegram.desktop") to open in it; known names (Telegram, Discord, Music, Notes) get suggested apps when apps is omitted. Reports bind conflicts with binds.json.`,
			`{"type":"object","properties":{"name":{"type":"string"},`+specialFields+`,"apps":{"type":"array","items":{"type":"string"},"description":"Desktop ids."}},"required":["name"],"additionalProperties":false}`,
			toolOpts{}, d.specialAdd),
		define("special_update", "Update special workspace",
			`Change a special workspace: newName (its open windows follow the rename), icon, accent, toggle, send, preload. Omitted fields are kept.`,
			`{"type":"object","properties":{`+specialRef+`,"newName":{"type":"string"},`+specialFields+`},"required":["name"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.specialUpdate),
		define("special_remove", "Remove special workspace",
			`Delete a special workspace (its binds go with it; open windows stay where they are).`,
			`{"type":"object","properties":{`+specialRef+`},"required":["name"],"additionalProperties":false}`,
			toolOpts{destructive: true, idempotent: true}, d.specialRemove),
		define("special_app_add", "Add app to special workspace",
			`Add an app to a special workspace: an installed desktop id (class and command are filled from it) and/or match (window class regex) + command. ifRunning: "nothing" (default) leaves a running instance where it is, "move" pulls it into the special on open. rule: its windows always open in the special.`,
			`{"type":"object","properties":{`+specialRef+`,"desktopId":{"type":"string"},"match":{"type":"string"},"command":{"type":"string"},"ifRunning":{"type":"string","enum":["nothing","move"]},"rule":{"type":"boolean"}},"required":["name"],"additionalProperties":false}`,
			toolOpts{}, d.specialAppAdd),
	}
}

func (d Deps) specialStore() (specials.Store, error) {
	_, store, err := d.catalog()
	if err != nil {
		return specials.Store{}, err
	}
	return specials.Store{Config: store}, nil
}

func (d Deps) appDirs() []string {
	if d.AppDirs != nil {
		return d.AppDirs
	}
	return specials.ApplicationDirs()
}

func (d Deps) loadSpecials() (specials.Store, []specials.Special, error) {
	s, err := d.specialStore()
	if err != nil {
		return s, nil, err
	}
	list, err := s.Load()
	return s, list, err
}

func findSpecial(list []specials.Special, ref string) (int, error) {
	if i, ok := specials.Find(list, ref); ok {
		return i, nil
	}
	names := []string{}
	for _, it := range list {
		names = append(names, it.Name)
	}
	return -1, fmt.Errorf("no special workspace %q (specials: %s)", ref, strings.Join(names, ", "))
}

// specialWindowCounts counts windows per special workspace name (best
// effort: empty without a compositor).
func (d Deps) specialWindowCounts(ctx context.Context) map[string]int {
	counts := map[string]int{}
	if !d.useDaemon() {
		return counts
	}
	out, err := d.runText(ctx, nil, brand.Daemon, "workspace", "list")
	if err != nil {
		return counts
	}
	ws, err := ParseDaemonWorkspaces([]byte(out))
	if err != nil {
		return counts
	}
	nameOf := map[string]string{}
	for _, w := range ws {
		nameOf[w.ID] = w.Name
	}
	wins, err := d.listWindows(ctx)
	if err != nil {
		return counts
	}
	for _, w := range wins {
		name := nameOf[w.Workspace]
		if name == "" && strings.HasPrefix(w.Workspace, "special:") {
			name = w.Workspace
		}
		if strings.HasPrefix(name, "special:") {
			counts[name]++
		}
	}
	return counts
}

func (d Deps) specialsList(ctx context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	_, list, err := d.loadSpecials()
	if err != nil {
		return nil, err
	}
	names := specials.HyprNames(list)
	counts := d.specialWindowCounts(ctx)
	type view struct {
		specials.Special
		Workspace string `json:"workspace"`
		Windows   int    `json:"windows"`
	}
	out := make([]view, 0, len(list))
	for _, it := range list {
		ws := "special:" + names[it.ID]
		out = append(out, view{Special: it, Workspace: ws, Windows: counts[ws]})
	}
	return mcp.JSONResult(map[string]any{"specials": out}), nil
}

func (d Deps) specialOpen(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	_, list, err := d.loadSpecials()
	if err != nil {
		return nil, err
	}
	i, err := findSpecial(list, a.Name)
	if err != nil {
		return nil, err
	}
	name := specials.HyprNames(list)[list[i].ID]
	if d.IPC != nil {
		if _, err := d.IPC.Call("ui.toggle", map[string]any{"command": "special:" + list[i].ID}); err == nil {
			return mcp.TextResult("Toggled " + list[i].Name + " (special:" + name + ")"), nil
		}
	}
	if !d.useDaemon() {
		return nil, fmt.Errorf("the shell is not running and %s is not available", brand.Daemon)
	}
	if _, err := d.runText(ctx, nil, brand.Daemon, "workspace", "toggle-special", name); err != nil {
		return nil, err
	}
	return mcp.TextResult("Toggled special:" + name), nil
}

type specialArgs struct {
	Name    string
	NewName *string
	Icon    *string
	Accent  *string
	Toggle  *string
	Send    *string
	Preload *bool
	Apps    []string
}

func (a specialArgs) apply(it *specials.Special) error {
	if a.NewName != nil {
		it.Name = strings.TrimSpace(*a.NewName)
	}
	if a.Icon != nil {
		it.Icon = *a.Icon
	}
	if a.Accent != nil {
		it.Accent = *a.Accent
	}
	if a.Preload != nil {
		it.Preload = *a.Preload
	}
	for _, f := range []struct {
		v   *string
		dst *specials.Combo
	}{{a.Toggle, &it.Toggle}, {a.Send, &it.Send}} {
		if f.v == nil {
			continue
		}
		c, err := specials.ParseCombo(*f.v)
		if err != nil {
			return err
		}
		*f.dst = c
	}
	return nil
}

func (d Deps) specialAdd(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a specialArgs
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	s, list, err := d.loadSpecials()
	if err != nil {
		return nil, err
	}
	list, it, err := specials.Add(list, a.Name, specials.IconFor(a.Name), "primary")
	if err != nil {
		return nil, err
	}
	idx := len(list) - 1
	if a.Apps == nil {
		list[idx].Apps = specials.SuggestApps(d.appDirs(), a.Name)
	}
	for _, id := range a.Apps {
		e, ok := specials.Lookup(d.appDirs(), id)
		if !ok {
			return nil, fmt.Errorf("no installed app %q", id)
		}
		list[idx].Apps = append(list[idx].Apps, e.App())
	}
	if err := a.apply(&list[idx]); err != nil {
		return nil, err
	}
	if err := s.Save(list); err != nil {
		return nil, err
	}
	return d.specialResult(list, it.ID, "added")
}

func (d Deps) specialUpdate(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a specialArgs
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	s, list, err := d.loadSpecials()
	if err != nil {
		return nil, err
	}
	i, err := findSpecial(list, a.Name)
	if err != nil {
		return nil, err
	}
	if err := a.apply(&list[i]); err != nil {
		return nil, err
	}
	if err := s.Save(list); err != nil {
		return nil, err
	}
	return d.specialResult(list, list[i].ID, "updated")
}

func (d Deps) specialRemove(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Name string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	s, list, err := d.loadSpecials()
	if err != nil {
		return nil, err
	}
	i, err := findSpecial(list, a.Name)
	if err != nil {
		return nil, err
	}
	name := list[i].Name
	if err := s.Save(append(list[:i], list[i+1:]...)); err != nil {
		return nil, err
	}
	return mcp.TextResult("Removed " + name), nil
}

func (d Deps) specialAppAdd(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Name, DesktopID, Match, Command, IfRunning string
		Rule                                       bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	s, list, err := d.loadSpecials()
	if err != nil {
		return nil, err
	}
	i, err := findSpecial(list, a.Name)
	if err != nil {
		return nil, err
	}
	var app specials.App
	if a.DesktopID != "" {
		e, ok := specials.Lookup(d.appDirs(), a.DesktopID)
		if !ok {
			return nil, fmt.Errorf("no installed app %q", a.DesktopID)
		}
		app = e.App()
	}
	if a.Match != "" {
		app.Match = a.Match
	}
	if a.Command != "" {
		app.Command = a.Command
	}
	app.IfRunning, app.Rule = a.IfRunning, a.Rule
	if app.Match == "" {
		return nil, fmt.Errorf("give desktopId or match")
	}
	list[i].Apps = append(list[i].Apps, app)
	list[i] = specials.Normalize(list[i])
	if err := s.Save(list); err != nil {
		return nil, err
	}
	return d.specialResult(list, list[i].ID, "app added")
}

// specialResult returns the item and the binds.json conflicts of its binds.
func (d Deps) specialResult(list []specials.Special, id, what string) (*mcp.CallToolResult, error) {
	i, _ := specials.Find(list, id)
	res := map[string]any{"result": what, "special": list[i], "workspace": "special:" + specials.HyprNames(list)[id]}
	if d.BindsFile != "" {
		if c, err := specials.Conflicts(d.BindsFile, list[i:i+1]); err == nil && len(c) > 0 {
			res["conflicts"] = c
		}
	}
	return mcp.JSONResult(res), nil
}
