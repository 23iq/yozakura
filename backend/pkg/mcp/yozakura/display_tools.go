package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/mcp"
)

// Display tools: screen brightness (through the compositor daemon:
// backlight or DDC/CI monitors), night light and caffeine (keep awake).

func displayTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("brightness_get", "Get brightness",
			`Screen brightness per display in percent (laptop backlight and external monitors over DDC/CI), with the display id usable as "monitor" in brightness_set.`,
			noArgs, toolOpts{readOnly: true}, d.brightnessGet),
		define("brightness_set", "Set brightness",
			`Set screen brightness. "percent": absolute 1-100, or "delta": relative change in points (e.g. -10). "monitor" limits it to one display from brightness_get (default: all).`,
			`{"type":"object","properties":{"percent":{"type":"number","minimum":1,"maximum":100},"delta":{"type":"number","minimum":-100,"maximum":100},"monitor":{"type":"string"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.brightnessSet),
		define("nightlight_set", "Night light",
			`Turn the night light (warm screen tint) on or off; omit "enabled" to toggle. "temperature" in kelvin (1000-6500, lower is warmer) changes the tint.`,
			`{"type":"object","properties":{"enabled":{"type":"boolean"},"temperature":{"type":"integer","minimum":1000,"maximum":6500}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.nightlightSet),
		define("caffeine_set", "Caffeine",
			`Keep the computer awake (no screen blanking, locking or suspend while idle) or allow idling again; omit "enabled" to toggle.`,
			`{"type":"object","properties":{"enabled":{"type":"boolean"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.caffeineSet),
	}
}

// Display is one brightness-controllable output.
type Display struct {
	ID      string `json:"id"`
	Kind    string `json:"kind"`
	Percent *int   `json:"percent,omitempty"`
}

// ParseBrightness decodes `<daemon> brightness list`.
func ParseBrightness(out string) ([]Display, error) {
	out = strings.TrimSpace(out)
	if strings.HasPrefix(out, "Error:") {
		return nil, fmt.Errorf("%s", strings.TrimSpace(strings.TrimPrefix(out, "Error:")))
	}
	var raw []struct {
		Name, Key, Kind string
		Brightness      *float64
	}
	if err := json.Unmarshal([]byte(out), &raw); err != nil {
		return nil, fmt.Errorf("brightness list: %v", err)
	}
	list := make([]Display, 0, len(raw))
	for _, r := range raw {
		dsp := Display{ID: r.Name, Kind: r.Kind}
		if r.Brightness != nil {
			p := int(math.Round(*r.Brightness * 100))
			dsp.Percent = &p
		}
		list = append(list, dsp)
	}
	return list, nil
}

func (d Deps) displays(ctx context.Context) ([]Display, error) {
	if !d.useDaemon() {
		return nil, fmt.Errorf("brightness control needs %s", brand.Daemon)
	}
	out, err := d.runText(ctx, nil, brand.Daemon, "brightness", "list")
	if err != nil {
		return nil, err
	}
	return ParseBrightness(out)
}

func (d Deps) brightnessGet(ctx context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	list, err := d.displays(ctx)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"displays": list}), nil
}

func (d Deps) brightnessSet(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Percent, Delta *float64
		Monitor        string
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Percent == nil && a.Delta == nil {
		return nil, fmt.Errorf("give percent or delta")
	}
	list, err := d.displays(ctx)
	if err != nil {
		return nil, err
	}
	var targets []Display
	for _, dsp := range list {
		if a.Monitor == "" || dsp.ID == a.Monitor {
			targets = append(targets, dsp)
		}
	}
	if len(targets) == 0 {
		return nil, fmt.Errorf("no display %q (see brightness_get)", a.Monitor)
	}
	results := []map[string]any{}
	var undos []map[string]any
	for _, t := range targets {
		cur := 50
		if t.Percent != nil {
			cur = *t.Percent
		}
		want := cur
		if a.Percent != nil {
			want = int(math.Round(*a.Percent))
		} else {
			want = cur + int(math.Round(*a.Delta))
		}
		want = max(1, min(100, want))
		out, err := d.runText(ctx, nil, brand.Daemon, "brightness", "set", t.ID, strconv.FormatFloat(float64(want)/100, 'f', 2, 64))
		if err == nil && strings.HasPrefix(out, "Error:") {
			err = fmt.Errorf("%s", strings.TrimSpace(strings.TrimPrefix(out, "Error:")))
		}
		if err != nil {
			return nil, fmt.Errorf("%s: %v", t.ID, err)
		}
		results = append(results, map[string]any{"id": t.ID, "percent": want, "was": cur})
		if t.Percent != nil && cur != want {
			undos = append(undos, map[string]any{"percent": cur, "monitor": t.ID})
		}
	}
	out := map[string]any{"displays": results}
	if len(undos) == 1 || (len(undos) > 0 && a.Monitor == "" && sameUndo(undos)) {
		args := undos[0]
		if len(undos) > 1 {
			delete(args, "monitor")
		}
		out["undo"] = undo("brightness_set", args)
	}
	return mcp.JSONResult(out), nil
}

// sameUndo: every display had the same level (one undo restores all).
func sameUndo(u []map[string]any) bool {
	for _, x := range u[1:] {
		if x["percent"] != u[0]["percent"] {
			return false
		}
	}
	return true
}

func (d Deps) nightlightSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Enabled     *bool
		Temperature int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	var cur struct {
		Active bool
		Temp   int
	}
	raw, err := d.call("nightlight.get", nil)
	if err != nil {
		return nil, err
	}
	_ = json.Unmarshal(raw, &cur)
	want := !cur.Active
	if a.Enabled != nil {
		want = *a.Enabled
	} else if a.Temperature > 0 {
		want = true
	}
	params := map[string]any{"enabled": want}
	if a.Temperature > 0 {
		params["temp"] = a.Temperature
	}
	var res struct {
		Active bool
		Temp   int
	}
	raw, err = d.call("nightlight.set", params)
	if err != nil {
		return nil, err
	}
	_ = json.Unmarshal(raw, &res)
	out := map[string]any{"enabled": res.Active, "temperature": res.Temp}
	if cur.Active != want || (a.Temperature > 0 && cur.Temp != a.Temperature) {
		back := map[string]any{"enabled": cur.Active}
		if cur.Temp > 0 {
			back["temperature"] = cur.Temp
		}
		out["undo"] = undo("nightlight_set", back)
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) caffeineSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Enabled *bool }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	var cur struct{ Inhibit bool }
	raw, err := d.call("caffeine.get", nil)
	if err != nil {
		return nil, err
	}
	_ = json.Unmarshal(raw, &cur)
	want := !cur.Inhibit
	if a.Enabled != nil {
		want = *a.Enabled
	}
	if _, err := d.call("caffeine.set", map[string]any{"inhibit": want}); err != nil {
		return nil, err
	}
	out := map[string]any{"enabled": want}
	if want != cur.Inhibit {
		out["undo"] = undo("caffeine_set", map[string]any{"enabled": cur.Inhibit})
	}
	return mcp.JSONResult(out), nil
}
