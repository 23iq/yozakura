package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"yozakura/backend/pkg/mcp"
)

// Window is the compositor-neutral window view.
type Window struct {
	ID         string `json:"id"`
	App        string `json:"app"`
	Title      string `json:"title"`
	Workspace  string `json:"workspace"`
	Monitor    string `json:"monitor"`
	Focused    bool   `json:"focused"`
	Floating   bool   `json:"floating"`
	Fullscreen bool   `json:"fullscreen"`
	X          int    `json:"x"`
	Y          int    `json:"y"`
	Width      int    `json:"width"`
	Height     int    `json:"height"`
}

// Workspace is the compositor-neutral workspace view.
type Workspace struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Monitor string `json:"monitor"`
	Active  bool   `json:"active"`
	Empty   bool   `json:"empty"`
	Windows int    `json:"windows"`
}

func desktopTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("wallpapers_list", "List wallpapers",
			`List wallpaper files (images and videos) in the wallpaper folder (or "dir"), plus the current wallpaper. Returns absolute paths usable with wallpaper_set.`,
			`{"type":"object","properties":{"dir":{"type":"string","description":"Folder to list; defaults to the shell's wallpaper folder."},"query":{"type":"string","description":"Case-insensitive substring filter on the file name."},"limit":{"type":"integer","minimum":1,"maximum":500,"default":100}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.wallpapersList),
		define("wallpaper_set", "Set wallpaper",
			`Set the desktop wallpaper to an image or video file (absolute path, ~ allowed). The color scheme is regenerated from it. "monitor" limits it to one output (e.g. "DP-1").`,
			`{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to an image (png/jpg/webp/...) or video (mp4/webm/...)."},"monitor":{"type":"string","description":"Optional output name; all monitors when omitted."}},"required":["path"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.wallpaperSet),
		define("windows_list", "List windows",
			`List open windows: id, app (class/app_id), title, workspace, monitor, focused/floating/fullscreen flags and geometry in pixels. Use the id with window_focus or window_move_to_workspace.`,
			`{"type":"object","properties":{"query":{"type":"string","description":"Optional case-insensitive filter on app or title."}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.windowsList),
		define("workspaces_list", "List workspaces",
			`List workspaces with id, name, monitor, whether each is the active one and how many windows it holds (special/scratchpad workspaces have names like "special:name").`,
			noArgs, toolOpts{readOnly: true}, d.workspacesList),
		define("window_focus", "Focus window",
			`Focus a window. Give "id" from windows_list, or "app"/"title" to match the first window whose app or title contains the text (case-insensitive).`,
			`{"type":"object","properties":{"id":{"type":"string"},"app":{"type":"string","description":"e.g. \"firefox\", \"kitty\"."},"title":{"type":"string"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.windowFocus),
		define("window_move_to_workspace", "Move window to workspace",
			`Move a window (default: the focused one) to a workspace id or name (e.g. 3 or "special:scratch"). "follow": true also switches to that workspace.`,
			`{"type":"object","properties":{"workspace":{"type":["string","integer"],"description":"Target workspace id or name."},"id":{"type":"string","description":"Window id from windows_list; focused window when omitted."},"app":{"type":"string","description":"Alternative to id: match by app."},"follow":{"type":"boolean","default":false}},"required":["workspace"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.windowMove),
		define("workspace_switch", "Switch workspace",
			`Switch the focused monitor to a workspace by id (e.g. 2) or name.`,
			`{"type":"object","properties":{"workspace":{"type":["string","integer"]}},"required":["workspace"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.workspaceSwitch),
	}
}

var mediaExt = map[string]bool{".png": true, ".jpg": true, ".jpeg": true, ".webp": true, ".gif": true, ".bmp": true,
	".avif": true, ".jxl": true, ".mp4": true, ".webm": true, ".mkv": true, ".mov": true}

func (d Deps) wallpaperState() (current, dir string) {
	data, err := os.ReadFile(d.WallpapersFile)
	if err != nil {
		return "", ""
	}
	var st struct {
		CurrentWall string `json:"currentWall"`
		WallPath    string `json:"wallPath"`
	}
	_ = json.Unmarshal(data, &st)
	dir = st.WallPath
	if dir == "" && st.CurrentWall != "" {
		dir = filepath.Dir(st.CurrentWall)
	}
	return st.CurrentWall, dir
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") || p == "~" {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, strings.TrimPrefix(p, "~"))
		}
	}
	return p
}

func (d Deps) wallpapersList(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Dir, Query string
		Limit      int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	current, dir := d.wallpaperState()
	if a.Dir != "" {
		dir = expandHome(a.Dir)
	}
	if dir == "" {
		return nil, fmt.Errorf("wallpaper folder unknown; pass \"dir\"")
	}
	if a.Limit <= 0 {
		a.Limit = 100
	}
	q := strings.ToLower(a.Query)
	var files []string
	total := 0
	_ = filepath.WalkDir(dir, func(p string, e os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if e.IsDir() {
			if p != dir && strings.HasPrefix(e.Name(), ".") {
				return filepath.SkipDir
			}
			return nil
		}
		if !mediaExt[strings.ToLower(filepath.Ext(p))] {
			return nil
		}
		if q != "" && !strings.Contains(strings.ToLower(filepath.Base(p)), q) {
			return nil
		}
		total++
		if len(files) < a.Limit {
			files = append(files, p)
		}
		return nil
	})
	sort.Strings(files)
	return mcp.JSONResult(map[string]any{"dir": dir, "current": current, "total": total, "files": files}), nil
}

func (d Deps) wallpaperSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Path, Monitor string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	p := expandHome(a.Path)
	if !filepath.IsAbs(p) {
		return nil, fmt.Errorf("path must be absolute: %q", a.Path)
	}
	st, err := os.Stat(p)
	if err != nil || st.IsDir() {
		return nil, fmt.Errorf("no such file: %s", p)
	}
	if !mediaExt[strings.ToLower(filepath.Ext(p))] {
		return nil, fmt.Errorf("not an image or video file: %s", p)
	}
	params := map[string]any{"path": p}
	if a.Monitor != "" {
		params["monitor"] = a.Monitor
	}
	if _, err := d.call("wallpaper.set", params); err != nil {
		return nil, err
	}
	return mcp.TextResult("Wallpaper set to " + p), nil
}
