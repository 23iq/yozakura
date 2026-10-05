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

// ShellPanels are the `ui.run` commands shell_toggle accepts.
var ShellPanels = []string{"launcher", "clipboard", "emoji", "notes", "dashboard", "wallpapers", "assistant",
	"overview", "powermenu", "tools", "config", "screenshot", "screenrecord", "lens", "lockscreen", "keybinds", "desktop-edit", "onboarding"}

func systemTools(d Deps) []mcp.ToolDef {
	panels, _ := json.Marshal(ShellPanels)
	return []mcp.ToolDef{
		define("notification_send", "Send notification",
			`Show a desktop notification. "urgency": low | normal | critical (critical stays until dismissed).`,
			`{"type":"object","properties":{"summary":{"type":"string","description":"Title line."},"body":{"type":"string","description":"Body text (basic markup allowed)."},"urgency":{"type":"string","enum":["low","normal","critical"],"default":"normal"}},"required":["summary"],"additionalProperties":false}`,
			toolOpts{}, d.notificationSend),
		define("notifications_list", "List notifications",
			`List recent notifications from the shell's history, newest first: app, summary, body, urgency, time (ISO-8601 when known).`,
			`{"type":"object","properties":{"limit":{"type":"integer","minimum":1,"maximum":200,"default":20},"app":{"type":"string","description":"Filter by app name (case-insensitive substring)."}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.notificationsList),
		define("clipboard_read", "Read clipboard",
			`Read the current clipboard as text. "primary": true reads the primary selection (the text currently highlighted). Non-text content is reported by MIME type instead.`,
			`{"type":"object","properties":{"primary":{"type":"boolean","default":false}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.clipboardRead),
		define("clipboard_write", "Write clipboard",
			`Copy text to the clipboard (replaces the current clipboard content).`,
			`{"type":"object","properties":{"text":{"type":"string"}},"required":["text"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.clipboardWrite),
		define("clipboard_history", "Clipboard history",
			`List clipboard history entries (newest first): id, MIME type, text preview (up to 200 chars), pinned flag.`,
			`{"type":"object","properties":{"limit":{"type":"integer","minimum":1,"maximum":100,"default":20}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.clipboardHistory),
		define("screenshot", "Take screenshot",
			`Capture the screen to a PNG file and return its absolute path. "mode": full (all outputs, or "output" e.g. "DP-1"), region (the user drags a rectangle with slurp), window (the focused window). Region mode waits for the user.`,
			`{"type":"object","properties":{"mode":{"type":"string","enum":["full","region","window"],"default":"full"},"output":{"type":"string","description":"Output name for full mode."},"copy":{"type":"boolean","default":false,"description":"Also copy the image to the clipboard."}},"additionalProperties":false}`,
			toolOpts{idempotent: false}, d.screenshot),
		define("media_control", "Control media",
			`Control media playback (MPRIS via playerctl). "action": play | pause | play-pause | next | previous | stop. "player" targets one player (e.g. "spotify", "firefox"); default is the active one.`,
			`{"type":"object","properties":{"action":{"type":"string","enum":["play","pause","play-pause","next","previous","stop"]},"player":{"type":"string"}},"required":["action"],"additionalProperties":false}`,
			toolOpts{}, d.mediaControl),
		define("media_status", "Media status",
			`List media players with status (Playing/Paused/Stopped), artist, title, album.`,
			noArgs, toolOpts{readOnly: true}, d.mediaStatus),
		define("volume_get", "Get volume",
			`Get the default output (or input with "source": true) volume as a percentage (0-150) and mute state.`,
			`{"type":"object","properties":{"source":{"type":"boolean","default":false,"description":"Microphone instead of speakers."}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.volumeGet),
		define("volume_set", "Set volume",
			`Set the default output (or input with "source": true) volume. "percent": absolute 0-150; or "delta": relative change in percent points (e.g. -10); "mute": true/false/"toggle".`,
			`{"type":"object","properties":{"percent":{"type":"number","minimum":0,"maximum":150},"delta":{"type":"number","minimum":-100,"maximum":100},"mute":{"type":["boolean","string"],"description":"true, false or \"toggle\""},"source":{"type":"boolean","default":false}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.volumeSet),
		define("dnd_set", "Do Not Disturb",
			`Turn Do Not Disturb (silences notification popups) on or off. Omit "enabled" to toggle.`,
			`{"type":"object","properties":{"enabled":{"type":"boolean"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.dndSet),
		define("shell_toggle", "Toggle shell panel",
			`Open or close a shell panel/tool (toggles). Panels: `+strings.Join(ShellPanels, ", ")+`.`,
			`{"type":"object","properties":{"panel":{"type":"string","enum":`+string(panels)+`}},"required":["panel"],"additionalProperties":false}`,
			toolOpts{}, d.shellToggle),
	}
}

func (d Deps) notificationSend(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Summary, Body, Urgency string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Summary == "" {
		return nil, fmt.Errorf("summary is required")
	}
	if a.Urgency == "" {
		a.Urgency = "normal"
	}
	_, err := d.call("notify.send", map[string]any{"summary": a.Summary, "body": a.Body, "urgency": a.Urgency, "appName": "Yozakura AI"})
	if err != nil {
		if _, ferr := d.runText(ctx, nil, "notify-send", "-a", "Yozakura AI", "-u", a.Urgency, a.Summary, a.Body); ferr != nil {
			return nil, fmt.Errorf("%v; notify-send: %v", err, ferr)
		}
	}
	return mcp.TextResult("Notification sent"), nil
}

func (d Deps) notificationsList(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Limit int
		App   string
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Limit <= 0 {
		a.Limit = 20
	}
	data, err := os.ReadFile(d.NotificationsFile)
	if err != nil {
		if os.IsNotExist(err) {
			return mcp.JSONResult(map[string]any{"notifications": []any{}}), nil
		}
		return nil, err
	}
	var raw []map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("notification history: %v", err)
	}
	type note struct {
		App     string `json:"app"`
		Summary string `json:"summary"`
		Body    string `json:"body"`
		Urgency any    `json:"urgency,omitempty"`
		Time    string `json:"time,omitempty"`
		t       float64
	}
	var out []note
	for _, n := range raw {
		app, _ := n["appName"].(string)
		if a.App != "" && !strings.Contains(strings.ToLower(app), strings.ToLower(a.App)) {
			continue
		}
		s, _ := n["summary"].(string)
		b, _ := n["body"].(string)
		nt := note{App: app, Summary: s, Body: truncate(b, 500), Urgency: urgencyName(n["urgency"])}
		switch tv := n["time"].(type) {
		case float64:
			nt.t = tv
			nt.Time = msToISO(tv)
		case string:
			nt.Time = tv
		}
		out = append(out, nt)
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].t > out[j].t })
	if len(out) > a.Limit {
		out = out[:a.Limit]
	}
	if out == nil {
		out = []note{}
	}
	return mcp.JSONResult(map[string]any{"notifications": out}), nil
}

func urgencyName(v any) any {
	if f, ok := v.(float64); ok {
		switch int(f) {
		case 0:
			return "low"
		case 2:
			return "critical"
		default:
			return "normal"
		}
	}
	return v
}

func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
}

func (d Deps) clipboardRead(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Primary bool }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	base := []string{}
	if a.Primary {
		base = append(base, "--primary")
	}
	types, err := d.runText(ctx, nil, "wl-paste", append(append([]string{}, base...), "--list-types")...)
	if err != nil {
		if strings.Contains(err.Error(), "No selection") || strings.Contains(err.Error(), "Nothing is copied") {
			return mcp.TextResult("(clipboard is empty)"), nil
		}
		return nil, err
	}
	hasText := false
	var mimes []string
	for _, t := range strings.Split(types, "\n") {
		t = strings.TrimSpace(t)
		if t == "" {
			continue
		}
		mimes = append(mimes, t)
		if strings.HasPrefix(t, "text/") || t == "UTF8_STRING" || t == "STRING" || t == "TEXT" {
			hasText = true
		}
	}
	if !hasText {
		return mcp.TextResult("(clipboard holds non-text data: " + strings.Join(mimes, ", ") + ")"), nil
	}
	text, err := d.runText(ctx, nil, "wl-paste", append(append([]string{}, base...), "--no-newline", "--type", "text")...)
	if err != nil {
		return nil, err
	}
	return mcp.TextResult(truncate(text, 100000)), nil
}

func (d Deps) clipboardWrite(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Text *string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Text == nil {
		return nil, fmt.Errorf("text is required")
	}
	if _, err := d.runText(ctx, []byte(*a.Text), "wl-copy"); err != nil {
		return nil, err
	}
	return mcp.TextResult(fmt.Sprintf("Copied %d characters", len([]rune(*a.Text)))), nil
}

func (d Deps) clipboardHistory(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Limit int }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Limit <= 0 {
		a.Limit = 20
	}
	raw, err := d.call("clipboard.list", nil)
	if err != nil {
		return nil, err
	}
	var items []map[string]any
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, fmt.Errorf("clipboard.list: %v", err)
	}
	type entry struct {
		ID      any    `json:"id"`
		Mime    string `json:"mime"`
		Preview string `json:"preview"`
		Pinned  bool   `json:"pinned"`
	}
	var out []entry
	for _, it := range items {
		if len(out) >= a.Limit {
			break
		}
		e := entry{ID: it["id"]}
		e.Mime, _ = it["mime"].(string)
		if e.Mime == "" {
			e.Mime, _ = it["mime_type"].(string)
		}
		p, _ := it["preview"].(string)
		e.Preview = truncate(p, 200)
		switch pv := it["pinned"].(type) {
		case bool:
			e.Pinned = pv
		case float64:
			e.Pinned = pv != 0
		}
		out = append(out, e)
	}
	if out == nil {
		out = []entry{}
	}
	return mcp.JSONResult(map[string]any{"items": out}), nil
}

func (d Deps) screenshotDir() string {
	if raw, err := d.call("screenshot.dir", nil); err == nil {
		var r struct {
			Dir string `json:"dir"`
		}
		if json.Unmarshal(raw, &r) == nil && r.Dir != "" {
			return r.Dir
		}
	}
	return d.ScreenshotDir
}

func (d Deps) screenshot(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Mode, Output string
		Copy         bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	dir := d.screenshotDir()
	if dir == "" {
		return nil, fmt.Errorf("screenshot folder unknown")
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	path := filepath.Join(dir, "Screenshot_"+d.now().Format("2006-01-02_15-04-05")+".png")
	grim := []string{}
	switch a.Mode {
	case "", "full":
		if a.Output != "" {
			grim = append(grim, "-o", a.Output)
		}
	case "region":
		geom, err := d.runText(ctx, nil, "slurp")
		if err != nil || geom == "" {
			return nil, fmt.Errorf("region selection cancelled")
		}
		grim = append(grim, "-g", geom)
	case "window":
		w, err := d.resolveWindow(ctx, "", "", "")
		if err != nil {
			return nil, fmt.Errorf("no focused window: %v", err)
		}
		grim = append(grim, "-g", fmt.Sprintf("%d,%d %dx%d", w.X, w.Y, w.Width, w.Height))
	default:
		return nil, fmt.Errorf("mode must be full, region or window")
	}
	grim = append(grim, path)
	if _, err := d.runText(ctx, nil, "grim", grim...); err != nil {
		return nil, err
	}
	if a.Copy {
		if data, err := os.ReadFile(path); err == nil {
			_, _ = d.runText(ctx, data, "wl-copy", "--type", "image/png")
		}
	}
	return mcp.JSONResult(map[string]any{"path": path}), nil
}

func (d Deps) dndSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Enabled *bool }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	cmd, msg := "dnd-toggle", "Do Not Disturb toggled"
	if a.Enabled != nil && *a.Enabled {
		cmd, msg = "dnd-on", "Do Not Disturb enabled"
	} else if a.Enabled != nil {
		cmd, msg = "dnd-off", "Do Not Disturb disabled"
	}
	if err := d.uiRun(cmd); err != nil {
		return nil, err
	}
	return mcp.TextResult(msg), nil
}

func (d Deps) shellToggle(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Panel string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	ok := false
	for _, p := range ShellPanels {
		if p == a.Panel {
			ok = true
		}
	}
	if !ok {
		return nil, fmt.Errorf("unknown panel %q; valid: %s", a.Panel, strings.Join(ShellPanels, ", "))
	}
	if err := d.uiRun(a.Panel); err != nil {
		return nil, err
	}
	return mcp.TextResult("Toggled " + a.Panel), nil
}
