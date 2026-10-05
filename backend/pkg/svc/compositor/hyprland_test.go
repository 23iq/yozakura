package compositor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"yozakura/backend/pkg/brand"
)

// overlaySample is the hl.config() table as the shell sends it (decoded
// from JSON, so numbers are float64 and lists are []any).
func overlaySample(t *testing.T) map[string]any {
	t.Helper()
	raw := `{
		"general": {
			"gaps_in": 8, "gaps_out": 18, "border_size": 2, "layout": "scrolling",
			"col": {
				"active_border": {"colors": ["rgb(feb0d1)", "rgb(f3b7c8)"], "angle": 45},
				"inactive_border": {"colors": ["rgba(3d363980)", "rgb(221a1c)"], "angle": 45}
			}
		},
		"decoration": {
			"rounding": 16, "active_opacity": 1, "inactive_opacity": 1,
			"shadow": {"enabled": true, "range": 20, "render_power": 3, "sharp": false,
				"color": "rgba(feb0d166)", "color_inactive": "rgba(00000066)", "offset": "0 0", "scale": 1},
			"blur": {"enabled": true, "size": 8, "passes": 3, "noise": 0.015, "contrast": 1.05,
				"brightness": 0.9, "vibrancy": 0.2, "vibrancy_darkness": 0, "popups": true,
				"popups_ignorealpha": 0.2, "special": true}
		}
	}`
	var m map[string]any
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func TestRenderTargetsDaemonFileOnlyWithOverlay(t *testing.T) {
	in := sampleInput()
	if out := Render(in, false); !strings.Contains(out, `hyprland = "hyprland.lua"`) {
		t.Fatalf("without overlay the daemon must keep writing hyprland.lua:\n%s", out[:120])
	}
	in.Hyprland = overlaySample(t)
	if out := Render(in, false); !strings.Contains(out, `hyprland = "`+DaemonHyprlandTarget+`"`) {
		t.Fatalf("with overlay the daemon must write its own hyprland file:\n%s", out[:120])
	}
}

func TestRenderTomlKeepsGradientAndShadowColor(t *testing.T) {
	in := sampleInput()
	in.Compositor.ActiveBorderColor = []string{"rgb(feb0d1)", "rgb(f3b7c8)"}
	in.Compositor.ActiveBorderAngle = 45
	in.Compositor.InactiveBorderColor = []string{"rgba(3d363980)", "rgb(221a1c)"}
	in.Compositor.Shadow.Color = "rgba(feb0d166)"
	out := Render(in, false)
	for _, want := range []string{
		`active_color = "rgb(feb0d1) rgb(f3b7c8) 45deg"`,
		`inactive_color = "rgba(3d363980)"`,
		`color = "rgba(feb0d166)"`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in TOML", want)
		}
	}
}

func TestFormatShadowColorsFallsBackForRoleNames(t *testing.T) {
	if got := formatShadowColors("shadow", 0.5); got != "rgba(00000080)" {
		t.Errorf("role name: got %q", got)
	}
	if got := formatShadowColors("rgba(feb0d166)", 0.4); got != "rgba(feb0d166)" {
		t.Errorf("literal: got %q", got)
	}
}

func TestRenderHyprlandLuaIsLossless(t *testing.T) {
	out := RenderHyprlandLua(overlaySample(t), "/data/yozakura/"+DaemonHyprlandTarget)
	for _, want := range []string{
		`local base = loadfile("/data/yozakura/` + DaemonHyprlandTarget + `")`,
		`pcall(hl.config, {`,
		`active_border = {`,
		`colors = { "rgb(feb0d1)", "rgb(f3b7c8)" },`,
		`angle = 45,`,
		`color = "rgba(feb0d166)",`,
		`color_inactive = "rgba(00000066)",`,
		`render_power = 3,`,
		`noise = 0.015,`,
		`contrast = 1.05,`,
		`vibrancy = 0.2,`,
		`vibrancy_darkness = 0,`,
		`popups = true,`,
		`popups_ignorealpha = 0.2,`,
		`layout = "scrolling",`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in Lua:\n%s", want, out)
		}
	}
}

func TestRenderHyprlandConfIsLossless(t *testing.T) {
	out := RenderHyprlandConf(overlaySample(t), "/data/yozakura/"+daemonHyprlandConf)
	for _, want := range []string{
		"source = /data/yozakura/" + daemonHyprlandConf + "\n",
		"general {\n",
		"    col.active_border = rgb(feb0d1) rgb(f3b7c8) 45deg\n",
		"    col.inactive_border = rgba(3d363980) rgb(221a1c) 45deg\n",
		"decoration {\n",
		"    shadow {\n",
		"        color = rgba(feb0d166)\n",
		"        color_inactive = rgba(00000066)\n",
		"        offset = 0 0\n",
		"    blur {\n",
		"        noise = 0.015\n",
		"        vibrancy_darkness = 0\n",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in conf:\n%s", want, out)
		}
	}
	if strings.Contains(out, "col {") {
		t.Error("col must be flattened into dotted keys, not a category")
	}
}

func TestGameModeOverlayDisablesEffectsWithoutMutatingInput(t *testing.T) {
	cfg := overlaySample(t)
	gm := gameModeHyprland(cfg)
	deco := gm["decoration"].(map[string]any)
	if deco["blur"].(map[string]any)["enabled"] != false || deco["shadow"].(map[string]any)["enabled"] != false {
		t.Error("gamemode must disable blur and shadow")
	}
	if deco["rounding"] != float64(0) || gm["general"].(map[string]any)["border_size"] != float64(1) {
		t.Error("gamemode must zero rounding and use a 1px border")
	}
	if gm["animations"].(map[string]any)["enabled"] != false {
		t.Error("gamemode must disable animations")
	}
	if cfg["decoration"].(map[string]any)["blur"].(map[string]any)["enabled"] != true {
		t.Error("input overlay must not be mutated")
	}
}

func TestServiceWriteEmitsEntryFilesBeforeToml(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, brand.DaemonConfigFile())
	svc := NewService(PathFunc(func() string { return path }))
	in := sampleInput()
	in.Hyprland = overlaySample(t)
	if _, err := svc.write(mustJSON(t, in)); err != nil {
		t.Fatalf("write: %v", err)
	}
	lua, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatalf("hyprland.lua not written: %v", err)
	}
	if !strings.Contains(string(lua), filepath.Join(dir, DaemonHyprlandTarget)) {
		t.Errorf("hyprland.lua must load the daemon's output:\n%s", lua)
	}
	conf, err := os.ReadFile(filepath.Join(dir, "hyprland.conf"))
	if err != nil {
		t.Fatalf("hyprland.conf not written: %v", err)
	}
	if !strings.Contains(string(conf), "source = "+filepath.Join(dir, daemonHyprlandConf)) {
		t.Errorf("hyprland.conf must source the daemon's output:\n%s", conf)
	}

	// Without an overlay (older shell) the entry files are left to yozd.
	dir2 := t.TempDir()
	path2 := filepath.Join(dir2, brand.DaemonConfigFile())
	svc2 := NewService(PathFunc(func() string { return path2 }))
	if _, err := svc2.write(mustJSON(t, sampleInput())); err != nil {
		t.Fatalf("write: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir2, "hyprland.lua")); !os.IsNotExist(err) {
		t.Error("no overlay: backend must not write hyprland.lua")
	}
}

func TestRenderHyprlandLuaStartsShellWithoutBase(t *testing.T) {
	old := shellBinary
	shellBinary = func() string { return "/opt/bin/yozakura" }
	defer func() { shellBinary = old }()
	out := RenderHyprlandLua(map[string]any{}, "/data/"+DaemonHyprlandTarget)
	want := "if base then\n    base()\nelse\n    hl.on(\"hyprland.start\", function()\n        hl.exec_cmd(\"/opt/bin/yozakura\")\n    end)\nend\n"
	if !strings.Contains(out, want) {
		t.Fatalf("missing fallback autostart:\n%s", out)
	}
}
