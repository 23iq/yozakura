package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/specials"
)

// App tools: installed applications (.desktop entries) and their windows.

func appTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("apps_find", "Find apps",
			`Search installed applications (.desktop entries) by name or id, e.g. "browser", "telegram", "files". Returns desktop id, name, icon and command, best match first. Use the id with app_launch or in a keybind (apps.launch).`,
			`{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":50,"default":10}},"required":["query"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.appsFind),
		define("app_launch", "Launch app",
			`Start an installed application by desktop id or name ("firefox", "Telegram"). "workspace" opens its window on that workspace (id like 3, or "special:name") without switching to it.`,
			`{"type":"object","properties":{"app":{"type":"string","description":"Desktop id (from apps_find) or app name."},"workspace":{"type":["string","integer"],"description":"Optional target workspace."}},"required":["app"],"additionalProperties":false}`,
			toolOpts{}, d.appLaunch),
		define("app_close", "Close app window",
			`Close a window (like clicking its close button; unsaved work may prompt or be lost). Give "id" from windows_list, or "app"/"title" to match the first window whose app id or title contains the text. Without any of them it closes nothing. Always confirm with the user before closing.`,
			`{"type":"object","properties":{"id":{"type":"string"},"app":{"type":"string"},"title":{"type":"string"}},"additionalProperties":false}`,
			toolOpts{destructive: true}, d.appClose),
	}
}

type appHit struct {
	e     specials.Entry
	score float64
}

// rankApps scores entries against a query: exact id/name, prefix, word
// prefix, substring of name, id or class.
func rankApps(entries []specials.Entry, query string) []appHit {
	q := strings.ToLower(strings.TrimSpace(query))
	if q == "" {
		return nil
	}
	var hits []appHit
	for _, e := range entries {
		name, id, class := strings.ToLower(e.Name), strings.ToLower(e.ID), strings.ToLower(e.StartupClass)
		s := 0.0
		switch {
		case id == q || name == q || class == q:
			s = 1
		case strings.HasPrefix(name, q) || strings.HasPrefix(id, q):
			s = 0.85
		case strings.HasSuffix(id, "."+q) || strings.Contains(" "+name, " "+q):
			s = 0.75
		case strings.Contains(name, q) || strings.Contains(id, q) || (class != "" && strings.Contains(class, q)):
			s = 0.6
		case strings.Contains(strings.ToLower(e.Exec), q):
			s = 0.4
		}
		if s > 0 {
			hits = append(hits, appHit{e, s})
		}
	}
	sort.SliceStable(hits, func(i, j int) bool {
		if hits[i].score != hits[j].score {
			return hits[i].score > hits[j].score
		}
		return len(hits[i].e.Name) < len(hits[j].e.Name)
	})
	return hits
}

func (d Deps) findApp(ref string) (specials.Entry, bool) {
	dirs := d.appDirs()
	if e, ok := specials.Lookup(dirs, ref); ok {
		return e, true
	}
	if hits := rankApps(specials.Entries(dirs), ref); len(hits) > 0 && hits[0].score >= 0.6 {
		return hits[0].e, true
	}
	return specials.Entry{}, false
}

func (d Deps) appsFind(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Query string
		Limit int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Limit <= 0 {
		a.Limit = 10
	}
	out := []map[string]any{}
	for _, h := range rankApps(specials.Entries(d.appDirs()), a.Query) {
		if len(out) >= a.Limit {
			break
		}
		out = append(out, map[string]any{"id": h.e.ID, "name": h.e.Name, "icon": h.e.Icon,
			"command": specials.StripFieldCodes(h.e.Exec)})
	}
	return mcp.JSONResult(map[string]any{"apps": out}), nil
}

func (d Deps) appLaunch(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		App       string
		Workspace any
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	e, ok := d.findApp(a.App)
	if !ok {
		return nil, fmt.Errorf("no installed app matches %q (try apps_find)", a.App)
	}
	ws := ""
	if a.Workspace != nil {
		ws = strings.TrimSpace(fmt.Sprint(a.Workspace))
	}
	if ws != "" {
		if !d.useDaemon() {
			return nil, fmt.Errorf("opening on a workspace needs %s", brand.Daemon)
		}
		target := ws
		if !strings.HasPrefix(ws, "special:") {
			target = ws + " silent"
		}
		if _, err := d.runText(ctx, nil, brand.Daemon, "system", "execute-in", target, specials.StripFieldCodes(e.Exec)); err != nil {
			return nil, err
		}
	} else {
		self, err := os.Executable()
		if err != nil {
			self = brand.AppID
		}
		if _, err := d.runText(ctx, nil, self, "launch", e.ID); err != nil {
			return nil, err
		}
	}
	out := map[string]any{"launched": e.ID, "name": e.Name}
	if ws != "" {
		out["workspace"] = ws
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) appClose(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID, App, Title string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.ID == "" && a.App == "" && a.Title == "" {
		return nil, fmt.Errorf("give id, app or title (see windows_list)")
	}
	w, err := d.resolveWindow(ctx, a.ID, a.App, a.Title)
	if err != nil {
		return nil, err
	}
	if d.useDaemon() {
		_, err = d.runText(ctx, nil, brand.Daemon, "window", "close", w.ID)
	} else {
		_, err = d.runText(ctx, nil, "hyprctl", "dispatch", "closewindow", "address:"+w.ID)
	}
	if err != nil {
		return nil, err
	}
	out := map[string]any{"closed": w.ID, "app": w.App, "title": w.Title}
	if e, ok := d.findApp(w.App); ok {
		out["undo"] = undo("app_launch", map[string]any{"app": e.ID})
	}
	return mcp.JSONResult(out), nil
}
