package compositor

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

type parityCase struct {
	Spec MotionSpec `json:"spec"`
	Lua  string     `json:"lua"`
}

func loadParity(t *testing.T) map[string]parityCase {
	t.Helper()
	raw, err := os.ReadFile("testdata/motion-parity.json")
	if err != nil {
		t.Fatal(err)
	}
	var all map[string]json.RawMessage
	if err := json.Unmarshal(raw, &all); err != nil {
		t.Fatal(err)
	}
	out := map[string]parityCase{}
	for k, v := range all {
		if strings.HasPrefix(k, "_") {
			continue
		}
		var c parityCase
		if err := json.Unmarshal(v, &c); err != nil {
			t.Fatal(err)
		}
		out[k] = c
	}
	return out
}

// The persisted Lua is line-per-statement; the live eval (MotionSpec.js
// luaChunk) is the same statements on one line.
func TestMotionLuaMatchesLiveEval(t *testing.T) {
	cases := loadParity(t)
	if len(cases) == 0 {
		t.Fatal("no parity cases")
	}
	for name, c := range cases {
		got := strings.Join(strings.Split(strings.TrimSuffix(MotionLua(c.Spec, false), "\n"), "\n"), " ")
		if got != c.Lua {
			t.Errorf("%s: Go Lua differs from MotionSpec.luaChunk\n got: %s\nwant: %s", name, got, c.Lua)
		}
	}
}

func TestMotionGameModeKeepsAnimationsOff(t *testing.T) {
	c := loadParity(t)["sakura"]
	if !strings.HasPrefix(MotionLua(c.Spec, true), "pcall(hl.config, { animations = { enabled = false } })") {
		t.Error("game mode must not re-enable animations")
	}
	if !strings.Contains(MotionConf(c.Spec, true), "    enabled = false\n") {
		t.Error("conf: game mode must keep animations off")
	}
}

func TestMotionConfUsesBezierFallbackForSprings(t *testing.T) {
	c := loadParity(t)["springs"]
	conf := MotionConf(c.Spec, false)
	for _, want := range []string{
		"animations {\n    enabled = true\n",
		"    bezier = springsBounce, 0.34, 1.56, 0.64, 1\n",
		"    animation = windowsIn, 1, 3.5, springsBounce, popin 80%\n",
		"    animation = windowsMove, 1, 3.5, springsSettle\n",
	} {
		if !strings.Contains(conf, want) {
			t.Errorf("conf missing %q\n%s", want, conf)
		}
	}
	if strings.Contains(conf, "spring =") {
		t.Error("hyprlang has no spring keyword")
	}
}

func TestOverlayFilesCarryMotionAndSmartGaps(t *testing.T) {
	c := loadParity(t)["sakura"]
	spec := c.Spec
	in := Input{Hyprland: map[string]any{"general": map[string]any{"gaps_in": 4.0}}, Motion: &spec, SmartGaps: true}
	files := HyprlandOverlayFiles(in, "/d", false)
	lua, conf := files["/d/hyprland.lua"], files["/d/hyprland.conf"]
	for _, want := range []string{
		`hl.curve("sakuraOvershoot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.08} } })`,
		`hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "sakuraLinear", style = "loop" })`,
		`__smartGapsRule = hl.workspace_rule({ workspace = "w[tv1]", gaps_in = 0, gaps_out = 0 })`,
	} {
		if !strings.Contains(lua, want) {
			t.Errorf("lua missing %q", want)
		}
	}
	// Motion comes after the appearance table so it wins over yozd's defaults.
	if strings.Index(lua, "pcall(hl.config, {\n") > strings.Index(lua, "sakuraOvershoot") {
		t.Error("motion must follow the appearance table")
	}
	if !strings.Contains(conf, "workspace = w[tv1], gapsout:0, gapsin:0\n") || !strings.Contains(conf, "bezier = sakuraEase, 0.25, 0.1, 0.25, 1\n") {
		t.Errorf("conf missing motion/smart gaps:\n%s", conf)
	}
	in.SmartGaps = false
	off := HyprlandOverlayFiles(in, "/d", false)
	if strings.Contains(off["/d/hyprland.lua"], "hl.workspace_rule") || strings.Contains(off["/d/hyprland.conf"], "w[tv1]") {
		t.Error("smart gaps off must not add the rule")
	}
	if !strings.Contains(off["/d/hyprland.lua"], "__smartGapsRule = nil") {
		t.Error("smart gaps off still resets the handle")
	}
}
