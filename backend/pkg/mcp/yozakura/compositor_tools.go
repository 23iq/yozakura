package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/mcp"
)

// --- compositor --------------------------------------------------------

// useDaemon reports whether the compositor daemon (brand.Daemon) is
// available; it is preferred over compositor-specific CLIs.
func (d Deps) useDaemon() bool { return d.Run != nil && d.Run.LookPath(brand.Daemon) }

func (d Deps) listWindows(ctx context.Context) ([]Window, error) {
	if d.useDaemon() {
		out, err := d.runText(ctx, nil, brand.Daemon, "window", "list")
		if err != nil {
			return nil, err
		}
		return ParseDaemonWindows([]byte(out))
	}
	out, err := d.runText(ctx, nil, "hyprctl", "clients", "-j")
	if err != nil {
		return nil, err
	}
	return ParseHyprClients([]byte(out))
}

// ParseDaemonWindows decodes `yozd window list`.
func ParseDaemonWindows(data []byte) ([]Window, error) {
	var raw []struct {
		AppID      string `json:"app_id"`
		ID         string `json:"id"`
		Floating   bool   `json:"is_floating"`
		Focused    bool   `json:"is_focused"`
		Fullscreen bool   `json:"is_fullscreen"`
		Title      string `json:"title"`
		Workspace  string `json:"workspace_id"`
		Meta       struct {
			Height, Width, X, Y int
			Monitor             string `json:"monitor_id"`
		} `json:"metadata"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("%s window list: %v", brand.Daemon, err)
	}
	out := make([]Window, 0, len(raw))
	for _, w := range raw {
		out = append(out, Window{ID: w.ID, App: w.AppID, Title: w.Title, Workspace: w.Workspace, Monitor: w.Meta.Monitor,
			Focused: w.Focused, Floating: w.Floating, Fullscreen: w.Fullscreen, X: w.Meta.X, Y: w.Meta.Y, Width: w.Meta.Width, Height: w.Meta.Height})
	}
	return out, nil
}

// ParseHyprClients decodes `hyprctl clients -j`.
func ParseHyprClients(data []byte) ([]Window, error) {
	var raw []struct {
		Address   string `json:"address"`
		Class     string `json:"class"`
		Title     string `json:"title"`
		Workspace struct {
			ID   int    `json:"id"`
			Name string `json:"name"`
		} `json:"workspace"`
		Monitor    json.RawMessage `json:"monitor"`
		Floating   bool            `json:"floating"`
		Fullscreen json.RawMessage `json:"fullscreen"`
		At         []int           `json:"at"`
		Size       []int           `json:"size"`
		FocusID    int             `json:"focusHistoryID"`
		Mapped     *bool           `json:"mapped"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("hyprctl clients: %v", err)
	}
	out := make([]Window, 0, len(raw))
	for _, w := range raw {
		if w.Mapped != nil && !*w.Mapped {
			continue
		}
		win := Window{ID: w.Address, App: w.Class, Title: w.Title, Workspace: strconv.Itoa(w.Workspace.ID),
			Monitor: strings.Trim(string(w.Monitor), `"`), Floating: w.Floating, Focused: w.FocusID == 0}
		fs := strings.Trim(string(w.Fullscreen), `"`)
		win.Fullscreen = fs == "true" || (fs != "" && fs != "false" && fs != "0")
		if len(w.At) == 2 {
			win.X, win.Y = w.At[0], w.At[1]
		}
		if len(w.Size) == 2 {
			win.Width, win.Height = w.Size[0], w.Size[1]
		}
		out = append(out, win)
	}
	return out, nil
}

func (d Deps) windowsList(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Query string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	wins, err := d.listWindows(ctx)
	if err != nil {
		return nil, err
	}
	if a.Query != "" {
		q := strings.ToLower(a.Query)
		var f []Window
		for _, w := range wins {
			if strings.Contains(strings.ToLower(w.App), q) || strings.Contains(strings.ToLower(w.Title), q) {
				f = append(f, w)
			}
		}
		wins = f
	}
	if wins == nil {
		wins = []Window{}
	}
	return mcp.JSONResult(map[string]any{"windows": wins}), nil
}

// ParseDaemonWorkspaces decodes `yozd workspace list`.
func ParseDaemonWorkspaces(data []byte) ([]Workspace, error) {
	var raw []struct {
		ID      string `json:"id"`
		Active  bool   `json:"is_active"`
		Empty   bool   `json:"is_empty"`
		Monitor string `json:"monitor_id"`
		Name    string `json:"name"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("%s workspace list: %v", brand.Daemon, err)
	}
	out := make([]Workspace, 0, len(raw))
	for _, w := range raw {
		out = append(out, Workspace{ID: w.ID, Name: w.Name, Monitor: w.Monitor, Active: w.Active, Empty: w.Empty})
	}
	return out, nil
}

// ParseHyprWorkspaces decodes `hyprctl workspaces -j` plus the active id.
func ParseHyprWorkspaces(data []byte, activeID int) ([]Workspace, error) {
	var raw []struct {
		ID      int    `json:"id"`
		Name    string `json:"name"`
		Monitor string `json:"monitor"`
		Windows int    `json:"windows"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("hyprctl workspaces: %v", err)
	}
	sort.Slice(raw, func(i, j int) bool { return raw[i].ID < raw[j].ID })
	out := make([]Workspace, 0, len(raw))
	for _, w := range raw {
		out = append(out, Workspace{ID: strconv.Itoa(w.ID), Name: w.Name, Monitor: w.Monitor, Active: w.ID == activeID,
			Empty: w.Windows == 0, Windows: w.Windows})
	}
	return out, nil
}

func (d Deps) workspacesList(ctx context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	var ws []Workspace
	if d.useDaemon() {
		out, err := d.runText(ctx, nil, brand.Daemon, "workspace", "list")
		if err != nil {
			return nil, err
		}
		if ws, err = ParseDaemonWorkspaces([]byte(out)); err != nil {
			return nil, err
		}
		if wins, err := d.listWindows(ctx); err == nil {
			counts := map[string]int{}
			for _, w := range wins {
				counts[w.Workspace]++
			}
			for i := range ws {
				ws[i].Windows = counts[ws[i].ID]
			}
		}
	} else {
		out, err := d.runText(ctx, nil, "hyprctl", "workspaces", "-j")
		if err != nil {
			return nil, err
		}
		active := 0
		if aout, err := d.runText(ctx, nil, "hyprctl", "activeworkspace", "-j"); err == nil {
			var a struct {
				ID int `json:"id"`
			}
			_ = json.Unmarshal([]byte(aout), &a)
			active = a.ID
		}
		if ws, err = ParseHyprWorkspaces([]byte(out), active); err != nil {
			return nil, err
		}
	}
	return mcp.JSONResult(map[string]any{"workspaces": ws}), nil
}

func (d Deps) resolveWindow(ctx context.Context, id, app, title string) (*Window, error) {
	wins, err := d.listWindows(ctx)
	if err != nil {
		return nil, err
	}
	for i := range wins {
		w := &wins[i]
		switch {
		case id != "" && w.ID == id:
			return w, nil
		case id == "" && app != "" && strings.Contains(strings.ToLower(w.App), strings.ToLower(app)):
			return w, nil
		case id == "" && app == "" && title != "" && strings.Contains(strings.ToLower(w.Title), strings.ToLower(title)):
			return w, nil
		case id == "" && app == "" && title == "" && w.Focused:
			return w, nil
		}
	}
	return nil, fmt.Errorf("no matching window (id=%q app=%q title=%q); call windows_list", id, app, title)
}

func (d Deps) windowFocus(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID, App, Title string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.ID == "" && a.App == "" && a.Title == "" {
		return nil, fmt.Errorf("give id, app or title")
	}
	w, err := d.resolveWindow(ctx, a.ID, a.App, a.Title)
	if err != nil {
		return nil, err
	}
	if d.useDaemon() {
		_, err = d.runText(ctx, nil, brand.Daemon, "window", "focus", w.ID)
	} else {
		_, err = d.runText(ctx, nil, "hyprctl", "dispatch", "focuswindow", "address:"+w.ID)
	}
	if err != nil {
		return nil, err
	}
	return mcp.TextResult(fmt.Sprintf("Focused %s — %s", w.App, w.Title)), nil
}

func wsArg(v json.RawMessage) (string, error) {
	var s string
	if json.Unmarshal(v, &s) == nil && s != "" {
		return s, nil
	}
	var n json.Number
	if json.Unmarshal(v, &n) == nil && n != "" {
		return n.String(), nil
	}
	return "", fmt.Errorf("workspace is required (id or name)")
}

func (d Deps) windowMove(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Workspace json.RawMessage
		ID, App   string
		Follow    bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	ws, err := wsArg(a.Workspace)
	if err != nil {
		return nil, err
	}
	w, err := d.resolveWindow(ctx, a.ID, a.App, "")
	if err != nil {
		return nil, err
	}
	if d.useDaemon() {
		if a.Follow {
			_, err = d.runText(ctx, nil, brand.Daemon, "workspace", "move-to", ws, w.ID)
			if err == nil {
				_, err = d.runText(ctx, nil, brand.Daemon, "workspace", "switch", ws)
			}
		} else {
			_, err = d.runText(ctx, nil, brand.Daemon, "window", "move-to-workspace-silent", ws, w.ID)
		}
	} else {
		disp := "movetoworkspacesilent"
		if a.Follow {
			disp = "movetoworkspace"
		}
		_, err = d.runText(ctx, nil, "hyprctl", "dispatch", disp, ws+",address:"+w.ID)
	}
	if err != nil {
		return nil, err
	}
	return mcp.TextResult(fmt.Sprintf("Moved %s — %s to workspace %s", w.App, w.Title, ws)), nil
}

func (d Deps) workspaceSwitch(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Workspace json.RawMessage }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	ws, err := wsArg(a.Workspace)
	if err != nil {
		return nil, err
	}
	if d.useDaemon() {
		_, err = d.runText(ctx, nil, brand.Daemon, "workspace", "switch", ws)
	} else {
		_, err = d.runText(ctx, nil, "hyprctl", "dispatch", "workspace", ws)
	}
	if err != nil {
		return nil, err
	}
	return mcp.TextResult("Switched to workspace " + ws), nil
}
