package yozakura

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/mcp"

	"github.com/stretchr/testify/assert"
)

// repoRoot holds config/defaults/*.js.
const repoRoot = "../../../.."

type call struct {
	Name  string
	Args  []string
	Stdin string
}

type fakeRunner struct {
	mu    sync.Mutex
	calls []call
	out   map[string]string // "name arg1 arg2" -> stdout
	errs  map[string]error
	bins  map[string]bool
}

func (f *fakeRunner) Run(_ context.Context, stdin []byte, name string, args ...string) ([]byte, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, call{name, args, string(stdin)})
	key := strings.TrimSpace(name + " " + strings.Join(args, " "))
	for k, err := range f.errs {
		if strings.HasPrefix(key, k) {
			return nil, err
		}
	}
	for k, v := range f.out {
		if strings.HasPrefix(key, k) {
			return []byte(v), nil
		}
	}
	return nil, nil
}

func (f *fakeRunner) LookPath(name string) bool { return f.bins[name] }

func (f *fakeRunner) last() call {
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.calls) == 0 {
		return call{}
	}
	return f.calls[len(f.calls)-1]
}

type ipcCall struct {
	Method string
	Params any
}

type fakeIPC struct {
	mu     sync.Mutex
	calls  []ipcCall
	down   bool
	result map[string]string
}

func (f *fakeIPC) Call(method string, params any) (json.RawMessage, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.down {
		return nil, errors.New("connect: no such file")
	}
	f.calls = append(f.calls, ipcCall{method, params})
	if r, ok := f.result[method]; ok {
		return json.RawMessage(r), nil
	}
	return json.RawMessage(`{"ok":true}`), nil
}

func readFile(t *testing.T, name string) string {
	data, err := os.ReadFile(filepath.Join("testdata", name))
	assert.NoError(t, err)
	return string(data)
}

func newDeps(t *testing.T) (Deps, *fakeRunner, *fakeIPC) {
	dir := t.TempDir()
	r := &fakeRunner{out: map[string]string{}, errs: map[string]error{}, bins: map[string]bool{}}
	ipc := &fakeIPC{result: map[string]string{}}
	return Deps{
		Run:               r,
		IPC:               ipc,
		ShellSource:       repoRoot,
		ConfigFile:        func(domain string) string { return filepath.Join(dir, domain+".json") },
		PresetsDir:        filepath.Join(dir, "presets"),
		ScreenshotDir:     filepath.Join(dir, "shots"),
		NotificationsFile: "testdata/notifications.json",
		WallpapersFile:    filepath.Join(dir, "wallpapers.json"),
		StateDir:          filepath.Join(dir, "state"),
		Now:               func() time.Time { return time.Date(2026, 10, 5, 12, 30, 45, 0, time.UTC) },
	}, r, ipc
}

func callTool(t *testing.T, d Deps, name string, args string) *mcp.CallToolResult {
	t.Helper()
	srv := NewServer(d, "test")
	cr, sw, sr, cw := pipes()
	go func() { _ = srv.Serve(context.Background(), sr, sw); sw.Close() }()
	c := mcp.NewStreamClient(cr, cw)
	defer c.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := c.Initialize(ctx, mcp.Implementation{Name: "t", Version: "1"})
	assert.NoError(t, err)
	var a any
	assert.NoError(t, json.Unmarshal([]byte(args), &a))
	res, err := c.CallTool(ctx, name, a)
	assert.NoError(t, err)
	if res == nil {
		return &mcp.CallToolResult{IsError: true}
	}
	return res
}

func TestEveryToolIsWellFormed(t *testing.T) {
	d, _, _ := newDeps(t)
	names := map[string]bool{}
	for _, td := range Tools(d) {
		tl := td.Tool
		assert.False(t, names[tl.Name], "duplicate %s", tl.Name)
		names[tl.Name] = true
		assert.Greater(t, len(tl.Description), 40, tl.Name)
		var schema map[string]any
		assert.NoError(t, json.Unmarshal(tl.InputSchema, &schema), tl.Name)
		assert.Equal(t, "object", schema["type"], tl.Name)
		assert.NotNil(t, tl.Annotations.ReadOnlyHint, tl.Name)
	}
	for _, want := range []string{"config_schema", "config_get", "config_set", "config_describe", "config_search",
		"presets_list", "preset_apply", "preset_save", "preset_diff",
		"preset_show", "preset_mix", "preset_duplicate", "preset_rename", "preset_delete",
		"wallpaper_set", "wallpapers_list", "windows_list", "workspaces_list", "window_focus",
		"window_move_to_workspace", "workspace_switch", "notification_send", "notifications_list",
		"clipboard_read", "clipboard_write", "clipboard_history", "screenshot", "media_control",
		"media_status", "dnd_set", "shell_toggle", "volume_get", "volume_set", "shell_commands", "shell_command",
		"specials_list", "special_open", "special_add", "special_update", "special_remove", "special_app_add"} {
		assert.True(t, names[want], want)
	}
	ro := ReadOnlyToolNames()
	assert.Contains(t, ro, "config_get")
	assert.NotContains(t, ro, "config_set")
}

func TestConfigSetValidation(t *testing.T) {
	d, _, ipc := newDeps(t)
	ok := callTool(t, d, "config_set", `{"domain":"bar","key":"position","value":"bottom"}`)
	assert.False(t, ok.IsError, ok.Text())
	assert.Contains(t, ok.Text(), `"old": "top"`)
	assert.Contains(t, ok.Text(), `"new": "bottom"`)
	assert.Empty(t, ipc.calls, "config writes never need the daemon")
	data, _ := os.ReadFile(d.ConfigFile("bar"))
	assert.Contains(t, string(data), `"position": "bottom"`)

	full := callTool(t, d, "config_set", `{"key":"theme.roundness","value":12}`)
	assert.False(t, full.IsError, full.Text())

	bad := callTool(t, d, "config_set", `{"domain":"bar","key":"position","value":3}`)
	assert.True(t, bad.IsError)
	assert.Contains(t, bad.Text(), "must be a string")

	enum := callTool(t, d, "config_set", `{"key":"bar.position","value":"up"}`)
	assert.True(t, enum.IsError)
	assert.Contains(t, enum.Text(), "one of top, bottom, left, right")

	rng := callTool(t, d, "config_set", `{"key":"theme.roundness","value":99}`)
	assert.True(t, rng.IsError)
	assert.Contains(t, rng.Text(), "0..24")
	forced := callTool(t, d, "config_set", `{"key":"theme.roundness","value":99,"force":true}`)
	assert.False(t, forced.IsError, forced.Text())

	unknown := callTool(t, d, "config_set", `{"domain":"bar","key":"positon","value":"top"}`)
	assert.True(t, unknown.IsError)
	assert.Contains(t, unknown.Text(), "did you mean bar.position")

	dom := callTool(t, d, "config_set", `{"domain":"zzz","key":"a","value":1}`)
	assert.True(t, dom.IsError)
	assert.Contains(t, dom.Text(), "unknown config domain")

	obj := callTool(t, d, "config_set", `{"domain":"bar","key":"activities","value":{"enabled":false,"maxVisible":3}}`)
	assert.False(t, obj.IsError, obj.Text())
	assert.Contains(t, obj.Text(), "bar.activities.maxVisible")
	badObj := callTool(t, d, "config_set", `{"domain":"bar","key":"activities","value":{"enabled":"no"}}`)
	assert.True(t, badObj.IsError)

	items := callTool(t, d, "config_set", `{"key":"bar.layout.left","value":["launcher","nope"]}`)
	assert.True(t, items.IsError)
	assert.Contains(t, items.Text(), "bar.layout.left[1]")
}

func TestConfigSetKeepsOtherKeys(t *testing.T) {
	d, _, _ := newDeps(t)
	assert.NoError(t, os.WriteFile(d.ConfigFile("dock"), []byte(`{"keep":"me","enabled":true}`), 0o644))
	res := callTool(t, d, "config_set", `{"domain":"dock","key":"enabled","value":false}`)
	assert.False(t, res.IsError, res.Text())
	data, _ := os.ReadFile(d.ConfigFile("dock"))
	assert.Equal(t, "{\n  \"keep\": \"me\",\n  \"enabled\": false\n}", string(data), "order and unknown keys kept")
}

func TestConfigGetSchemaDescribeSearch(t *testing.T) {
	d, _, _ := newDeps(t)
	assert.NoError(t, os.WriteFile(d.ConfigFile("bar"), []byte(`{"position":"left"}`), 0o644))
	res := callTool(t, d, "config_get", `{"domain":"bar","key":"position"}`)
	assert.Contains(t, res.Text(), `"value": "left"`)
	res = callTool(t, d, "config_get", `{"key":"bar.compact"}`)
	assert.Contains(t, res.Text(), `"isDefault": true`)
	res = callTool(t, d, "config_get", `{"domain":"bar"}`)
	assert.Contains(t, res.Text(), `"position": "left"`)
	assert.Contains(t, res.Text(), `"deluge": "********"`, "credentials are masked")
	res = callTool(t, d, "config_schema", `{}`)
	assert.Contains(t, res.Text(), `"domain": "theme"`)
	res = callTool(t, d, "config_schema", `{"domain":"bar","prefix":"activities"}`)
	assert.Contains(t, res.Text(), `"key": "activities.enabled"`)
	assert.Contains(t, res.Text(), `"description"`)

	res = callTool(t, d, "config_describe", `{"key":"bar.layout.style"}`)
	assert.False(t, res.IsError, res.Text())
	assert.Contains(t, res.Text(), `"islands"`)
	assert.Contains(t, res.Text(), `"settingsPage"`)
	res = callTool(t, d, "config_describe", `{"domain":"bar","key":"position"}`)
	assert.Contains(t, res.Text(), `"current": "left"`)

	res = callTool(t, d, "config_search", `{"query":"rounded corners"}`)
	assert.Contains(t, res.Text(), "theme.roundness")
	assert.True(t, callTool(t, d, "config_search", `{"query":" "}`).IsError)
}

func TestPresetTools(t *testing.T) {
	d, _, _ := newDeps(t)
	res := callTool(t, d, "presets_list", `{}`)
	assert.Contains(t, res.Text(), "Yozakura Night")
	assert.True(t, callTool(t, d, "preset_apply", `{"name":"nope"}`).IsError)
	res = callTool(t, d, "preset_apply", `{"name":"yozakura night"}`)
	assert.False(t, res.IsError, res.Text())
	data, err := os.ReadFile(d.ConfigFile("bar"))
	assert.NoError(t, err)
	assert.NotEmpty(t, data)
	marker, _ := os.ReadFile(filepath.Join(d.PresetsDir, "active_preset"))
	assert.Equal(t, "Yozakura Night\n", string(marker))

	res = callTool(t, d, "preset_diff", `{"a":"current","b":"Yozakura Night"}`)
	assert.Contains(t, res.Text(), `"count": 0`)
	callTool(t, d, "config_set", `{"key":"theme.roundness","value":3}`)
	res = callTool(t, d, "preset_diff", `{"a":"Yozakura Night","b":"current"}`)
	assert.Contains(t, res.Text(), `"key": "theme.roundness"`)

	res = callTool(t, d, "preset_save", `{"name":"Mine","domains":["theme"]}`)
	assert.False(t, res.IsError, res.Text())
	assert.True(t, callTool(t, d, "preset_save", `{"name":"Mine"}`).IsError, "exists")
	assert.False(t, callTool(t, d, "preset_save", `{"name":"Mine","overwrite":true}`).IsError)
	assert.True(t, callTool(t, d, "preset_save", `{"name":"Yozakura Night"}`).IsError, "built-in name")
	assert.True(t, callTool(t, d, "preset_save", `{"name":"x","domains":["ai"]}`).IsError, "excluded domain")

	res = callTool(t, d, "preset_duplicate", `{"name":"Neon Tokyo","newName":"Neon Mine"}`)
	assert.False(t, res.IsError, res.Text())
	res = callTool(t, d, "preset_mix", `{"name":"Blend","sources":{"layout":"Kaze","colors":"Neon Mine"}}`)
	assert.False(t, res.IsError, res.Text())
	assert.True(t, callTool(t, d, "preset_mix", `{"name":"Bad","sources":{"nope":"CRT"}}`).IsError)
	res = callTool(t, d, "preset_show", `{"name":"Blend"}`)
	assert.Contains(t, res.Text(), `"Kaze"`)
	assert.Contains(t, res.Text(), `"id": "layout"`)
	assert.True(t, callTool(t, d, "preset_rename", `{"name":"Sumi-e","newName":"x"}`).IsError, "built-ins are read-only")
	assert.False(t, callTool(t, d, "preset_rename", `{"name":"Blend","newName":"Blend 2"}`).IsError)
	res = callTool(t, d, "preset_delete", `{"name":"Blend 2"}`)
	assert.False(t, res.IsError, res.Text())
	assert.Contains(t, res.Text(), `"restore"`)
}

// The glass system is reachable by AI agents through the generic config
// tools: nested keys are discovered, validated and patched leaf by leaf.
func TestConfigGlassKeys(t *testing.T) {
	d, _, _ := newDeps(t)
	res := callTool(t, d, "config_schema", `{"domain":"theme","prefix":"glass"}`)
	for _, k := range []string{"glass.amount", "glass.enabled", "glass.advanced.blurSize", "glass.surfaces.dock.amount", "glass.surfaces.windows.inactiveOpacity"} {
		assert.Contains(t, res.Text(), `"key": "`+k+`"`)
	}
	ok := callTool(t, d, "config_set", `{"domain":"theme","key":"glass.amount","value":0.6}`)
	assert.False(t, ok.IsError, ok.Text())
	data, _ := os.ReadFile(d.ConfigFile("theme"))
	assert.Contains(t, string(data), `"amount": 0.6`)
	auto := callTool(t, d, "config_set", `{"key":"theme.glass.amount","value":-1}`)
	assert.False(t, auto.IsError, "-1 = inherit/auto is always allowed: %s", auto.Text())
	far := callTool(t, d, "config_set", `{"key":"theme.glass.amount","value":3}`)
	assert.True(t, far.IsError)
	assert.Contains(t, far.Text(), "0..1 or -1")
	bad := callTool(t, d, "config_set", `{"domain":"theme","key":"glass.enabled","value":"yes"}`)
	assert.True(t, bad.IsError)
	obj := callTool(t, d, "config_set", `{"domain":"theme","key":"glass.surfaces","value":{"dock":{"amount":0},"terminal":{"amount":0.8}}}`)
	assert.False(t, obj.IsError, obj.Text())
	assert.Contains(t, obj.Text(), "theme.glass.surfaces.terminal.amount")
}

func TestHyprctlFallback(t *testing.T) {
	d, r, _ := newDeps(t)
	r.out["hyprctl clients -j"] = readFile(t, "hypr_clients.json")
	r.out["hyprctl workspaces -j"] = readFile(t, "hypr_workspaces.json")
	r.out["hyprctl activeworkspace -j"] = `{"id":3}`
	res := callTool(t, d, "windows_list", `{}`)
	var w struct{ Windows []Window }
	assert.NoError(t, json.Unmarshal([]byte(res.Text()), &w))
	assert.Len(t, w.Windows, 2, "unmapped windows are skipped")
	assert.Equal(t, Window{ID: "0xbbb", App: "kitty", Title: "nvim", Workspace: "3", Monitor: "1", Focused: true,
		Floating: true, Fullscreen: true, Width: 1920, Height: 1080}, w.Windows[1])

	res = callTool(t, d, "workspaces_list", `{}`)
	var ws struct{ Workspaces []Workspace }
	assert.NoError(t, json.Unmarshal([]byte(res.Text()), &ws))
	assert.Equal(t, "special:scratch", ws.Workspaces[0].Name)
	assert.True(t, ws.Workspaces[2].Active)

	callTool(t, d, "window_focus", `{"app":"FIRE"}`)
	assert.Equal(t, call{"hyprctl", []string{"dispatch", "focuswindow", "address:0xaaa"}, ""}, r.last())
	callTool(t, d, "window_move_to_workspace", `{"workspace":5}`)
	assert.Equal(t, call{"hyprctl", []string{"dispatch", "movetoworkspacesilent", "5,address:0xbbb"}, ""}, r.last())
	callTool(t, d, "workspace_switch", `{"workspace":"special:scratch"}`)
	assert.Equal(t, call{"hyprctl", []string{"dispatch", "workspace", "special:scratch"}, ""}, r.last())
	miss := callTool(t, d, "window_focus", `{"app":"nothing"}`)
	assert.True(t, miss.IsError)
}

func TestDaemonPreferred(t *testing.T) {
	d, r, _ := newDeps(t)
	r.bins[brand.Daemon] = true
	r.out[brand.Daemon+" window list"] = readFile(t, "daemon_windows.json")
	r.out[brand.Daemon+" workspace list"] = readFile(t, "daemon_workspaces.json")
	res := callTool(t, d, "workspaces_list", `{}`)
	var ws struct{ Workspaces []Workspace }
	assert.NoError(t, json.Unmarshal([]byte(res.Text()), &ws))
	assert.Equal(t, 1, ws.Workspaces[1].Windows)
	assert.True(t, ws.Workspaces[1].Active)
	callTool(t, d, "window_move_to_workspace", `{"workspace":"4","app":"firefox","follow":true}`)
	assert.Equal(t, call{brand.Daemon, []string{"workspace", "switch", "4"}, ""}, r.last())
	callTool(t, d, "window_focus", `{"title":"nvim"}`)
	assert.Equal(t, call{brand.Daemon, []string{"window", "focus", "0x2"}, ""}, r.last())
}

func TestClipboardTools(t *testing.T) {
	d, r, ipc := newDeps(t)
	r.out["wl-paste --list-types"] = "text/plain;charset=utf-8\nUTF8_STRING\n"
	r.out["wl-paste --no-newline --type text"] = "hello"
	assert.Equal(t, "hello", callTool(t, d, "clipboard_read", `{}`).Text())
	r.out["wl-paste --primary --list-types"] = "image/png\n"
	assert.Contains(t, callTool(t, d, "clipboard_read", `{"primary":true}`).Text(), "non-text data: image/png")

	callTool(t, d, "clipboard_write", `{"text":"copied ✓"}`)
	assert.Equal(t, call{"wl-copy", nil, "copied ✓"}, r.last())

	ipc.result["clipboard.list"] = `[{"id":"7","mime":"text/plain","preview":"abc","pinned":true},{"id":"8","mime":"image/png","preview":"","pinned":false}]`
	res := callTool(t, d, "clipboard_history", `{"limit":1}`)
	assert.Contains(t, res.Text(), `"preview": "abc"`)
	assert.NotContains(t, res.Text(), `"8"`)
}

func TestScreenshotPaths(t *testing.T) {
	d, r, ipc := newDeps(t)
	ipc.down = true // fall back to ScreenshotDir
	res := callTool(t, d, "screenshot", `{}`)
	want := filepath.Join(d.ScreenshotDir, "Screenshot_2026-10-05_12-30-45.png")
	assert.Contains(t, res.Text(), want)
	assert.Equal(t, call{"grim", []string{want}, ""}, r.last())

	r.out["slurp"] = "10,20 300x200\n"
	callTool(t, d, "screenshot", `{"mode":"region"}`)
	assert.Equal(t, []string{"-g", "10,20 300x200", want}, r.last().Args)

	r.out["hyprctl clients -j"] = readFile(t, "hypr_clients.json")
	callTool(t, d, "screenshot", `{"mode":"window"}`)
	assert.Equal(t, []string{"-g", "0,0 1920x1080", want}, r.last().Args)

	ipc.down = false
	dir := t.TempDir()
	ipc.result["screenshot.dir"] = `{"dir":"` + dir + `"}`
	res = callTool(t, d, "screenshot", `{"mode":"full","output":"DP-1"}`)
	assert.Contains(t, res.Text(), dir)
	assert.Equal(t, []string{"-o", "DP-1", filepath.Join(dir, "Screenshot_2026-10-05_12-30-45.png")}, r.last().Args)

	r.errs["slurp"] = errors.New("cancelled")
	assert.True(t, callTool(t, d, "screenshot", `{"mode":"region"}`).IsError)
}

func TestDndAndShellToggleUseUIRun(t *testing.T) {
	d, _, ipc := newDeps(t)
	callTool(t, d, "dnd_set", `{"enabled":true}`)
	callTool(t, d, "dnd_set", `{"enabled":false}`)
	callTool(t, d, "dnd_set", `{}`)
	callTool(t, d, "shell_toggle", `{"panel":"launcher"}`)
	var cmds []string
	for _, c := range ipc.calls {
		assert.Equal(t, "ui.run", c.Method)
		cmds = append(cmds, c.Params.(map[string]any)["command"].(string))
	}
	assert.Equal(t, []string{"dnd-on", "dnd-off", "dnd-toggle", "launcher"}, cmds)
	bad := callTool(t, d, "shell_toggle", `{"panel":"rm -rf"}`)
	assert.True(t, bad.IsError)
}

func TestNotificationsTools(t *testing.T) {
	d, r, ipc := newDeps(t)
	res := callTool(t, d, "notifications_list", `{"limit":2}`)
	text := res.Text()
	assert.Less(t, strings.Index(text, "Download"), strings.Index(text, "Build done"), "newest first")
	assert.NotContains(t, text, "Old")
	assert.Contains(t, text, `"urgency": "critical"`)
	res = callTool(t, d, "notifications_list", `{"app":"KITTY"}`)
	assert.NotContains(t, res.Text(), "Download")

	callTool(t, d, "notification_send", `{"summary":"Hi","body":"there"}`)
	assert.Equal(t, "notify.send", ipc.calls[0].Method)
	ipc.down = true
	callTool(t, d, "notification_send", `{"summary":"Hi","urgency":"critical"}`)
	assert.Equal(t, "notify-send", r.last().Name)
	assert.Contains(t, r.last().Args, "critical")
}

func TestMediaAndVolume(t *testing.T) {
	d, r, _ := newDeps(t)
	callTool(t, d, "media_control", `{"action":"next","player":"spotify"}`)
	assert.Equal(t, call{"playerctl", []string{"--player", "spotify", "next"}, ""}, r.last())
	assert.True(t, callTool(t, d, "media_control", `{"action":"explode"}`).IsError)
	r.out["playerctl -a metadata"] = "spotify\tPlaying\tArtist\tSong\tAlbum\nfirefox\tPaused\t\tVideo\t\n"
	res := callTool(t, d, "media_status", `{}`)
	assert.Contains(t, res.Text(), `"title": "Song"`)
	assert.Contains(t, res.Text(), `"player": "firefox"`)

	r.out["wpctl get-volume"] = "Volume: 0.45 [MUTED]"
	res = callTool(t, d, "volume_get", `{}`)
	assert.Contains(t, res.Text(), `"percent": 45`)
	assert.Contains(t, res.Text(), `"muted": true`)
	callTool(t, d, "volume_set", `{"percent":200}`)
	found := false
	for _, c := range r.calls {
		if c.Name == "wpctl" && len(c.Args) > 0 && c.Args[0] == "set-volume" {
			assert.Equal(t, []string{"set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "1.50"}, c.Args)
			found = true
		}
	}
	assert.True(t, found)
	callTool(t, d, "volume_set", `{"delta":-10,"source":true}`)
	callTool(t, d, "volume_set", `{"mute":"toggle"}`)
	var setCalls [][]string
	for _, c := range r.calls {
		if c.Name == "wpctl" && c.Args[0] != "get-volume" {
			setCalls = append(setCalls, c.Args)
		}
	}
	assert.Contains(t, setCalls, []string{"set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SOURCE@", "10%-"})
	assert.Contains(t, setCalls, []string{"set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"})
	assert.True(t, callTool(t, d, "volume_set", `{}`).IsError)
}

func TestWallpaperTools(t *testing.T) {
	d, _, ipc := newDeps(t)

	walls := t.TempDir()
	for _, f := range []string{"a.png", "b.mp4", "notes.txt", ".hidden/c.jpg"} {
		p := filepath.Join(walls, f)
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		assert.NoError(t, os.WriteFile(p, []byte("x"), 0o644))
	}
	assert.NoError(t, os.WriteFile(d.WallpapersFile, []byte(`{"currentWall":"`+walls+`/a.png","wallPath":"`+walls+`"}`), 0o644))
	res := callTool(t, d, "wallpapers_list", `{}`)
	assert.Contains(t, res.Text(), "b.mp4")
	assert.NotContains(t, res.Text(), "notes.txt")
	assert.NotContains(t, res.Text(), "c.jpg")
	assert.Contains(t, res.Text(), `"total": 2`)

	assert.True(t, callTool(t, d, "wallpaper_set", `{"path":"relative.png"}`).IsError)
	assert.True(t, callTool(t, d, "wallpaper_set", `{"path":"`+walls+`/notes.txt"}`).IsError)
	assert.True(t, callTool(t, d, "wallpaper_set", `{"path":"`+walls+`/missing.png"}`).IsError)
	ipc.calls = nil
	assert.False(t, callTool(t, d, "wallpaper_set", `{"path":"`+walls+`/b.mp4","monitor":"DP-1"}`).IsError)
	assert.Equal(t, map[string]any{"path": walls + "/b.mp4", "monitor": "DP-1"}, ipc.calls[0].Params)
}
