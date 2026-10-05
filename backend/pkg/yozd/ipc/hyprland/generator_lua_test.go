package hyprland

import (
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestDispatcherToLuaMovefocusMonocle(t *testing.T) {
	cases := []struct {
		arg      string
		wantAny  []string // substrings that must appear in the generated Lua
		wantNone []string // substrings that must NOT appear
	}{
		{
			arg: "u",
			wantAny: []string{
				`layout == "monocle"`,
				`hl.dsp.layout("cyclenext")`,
				`hl.dsp.focus({ direction = "u" })`,
			},
			wantNone: []string{
				`hl.dsp.layout("focus u")`,
			},
		},
		{
			arg: "r",
			wantAny: []string{
				`hl.dsp.layout("cyclenext")`,
			},
		},
		{
			arg: "d",
			wantAny: []string{
				`hl.dsp.layout("cycleprev")`,
			},
		},
		{
			arg: "l",
			wantAny: []string{
				`hl.dsp.layout("cycleprev")`,
			},
		},
	}
	for _, c := range cases {
		t.Run(c.arg, func(t *testing.T) {
			lua := dispatcherToLua("movefocus", c.arg)
			for _, want := range c.wantAny {
				if !strings.Contains(lua, want) {
					t.Errorf("movefocus %q: missing %q in:\n%s", c.arg, want, lua)
				}
			}
			for _, unwanted := range c.wantNone {
				if strings.Contains(lua, unwanted) {
					t.Errorf("movefocus %q: unexpected %q in:\n%s", c.arg, unwanted, lua)
				}
			}
		})
	}
}

func TestDispatcherToLuaMovefocusDropsScrollingBranch(t *testing.T) {
	// Scrolling must go through the generic dispatcher so focus can
	// fall back to the neighbor monitor; layoutmsg focus never does.
	for _, arg := range []string{"u", "d", "l", "r"} {
		lua := dispatcherToLua("movefocus", arg)
		if strings.Contains(lua, `hl.dsp.layout("focus `+arg+`")`) || strings.Contains(lua, `layout == "scrolling"`) {
			t.Errorf("movefocus %q: scrolling layoutmsg branch still present:\n%s", arg, lua)
		}
	}
}

func TestDispatcherToLuaMovewindowMonocleCycles(t *testing.T) {
	cases := []struct {
		arg     string
		wantAny string
	}{
		{"u", `hl.dsp.layout("cyclenext")`},
		{"r", `hl.dsp.layout("cyclenext")`},
		{"d", `hl.dsp.layout("cycleprev")`},
		{"l", `hl.dsp.layout("cycleprev")`},
	}
	for _, c := range cases {
		t.Run(c.arg, func(t *testing.T) {
			lua := dispatcherToLua("movewindow", c.arg)
			if !strings.Contains(lua, c.wantAny) {
				t.Errorf("movewindow %q: missing %q in:\n%s", c.arg, c.wantAny, lua)
			}
			if !strings.Contains(lua, `layout == "monocle"`) {
				t.Errorf("movewindow %q: missing monocle branch in:\n%s", c.arg, lua)
			}
		})
	}
}

func TestDispatcherToLuaMovewindowNonMonocleStaysDirect(t *testing.T) {
	lua := dispatcherToLua("movewindow", "u")
	if !strings.Contains(lua, `hl.dsp.window.move({ direction = "u" })`) {
		t.Errorf("non-monocle branch lost; got:\n%s", lua)
	}
}

func TestDispatcherToLuaMovewindowDragUnchanged(t *testing.T) {
	lua := dispatcherToLua("movewindow", "")
	want := "hl.dsp.window.drag()"
	if lua != want {
		t.Errorf("drag variant regressed: got %q, want %q", lua, want)
	}
}

// Each Lua section generator should be banner-free. The orchestrator in
// pkg/server writes the banner exactly once at the top of the file.
func TestLuaSectionsAreBannerFree(t *testing.T) {
	gen := NewLuaGenerator()
	banner := "(do not edit)"

	sections := []string{
		gen.GenerateAppearanceLua(ipc.ConfigAppearance{}),
		gen.GenerateKeybindsLua(ipc.ConfigKeybinds{}),
		gen.GenerateWindowRulesLua(nil),
		gen.GenerateLayerRulesLua(nil),
	}
	for _, sec := range sections {
		if strings.Contains(sec, banner) {
			t.Errorf("section generator leaked the banner; section:\n%s", sec)
		}
	}

	if got := gen.GenerateStartupLua([]string{"notify-send hi"}, []string{"yozakura"}); strings.Contains(got, banner) {
		t.Errorf("GenerateStartupLua leaked the banner:\n%s", got)
	}
	if got := gen.GenerateStartupLua(nil, nil); strings.Contains(got, banner) {
		t.Errorf("empty GenerateStartupLua leaked the banner:\n%s", got)
	}
}

// Workspaces animation style defaults to slidefade, follows the
// Animations.WorkspaceStyle override when set. Used by the shell to
// switch between slidefade (vertical bar) and slidefadevert
// (horizontal bar) without a Timer-based live patch.
func TestLuaAppearanceWorkspaceStyleDefault(t *testing.T) {
	gen := NewLuaGenerator()
	enabled := true
	out := gen.GenerateAppearanceLua(ipc.ConfigAppearance{
		Animations: &ipc.Animations{Enabled: &enabled},
	})
	if !strings.Contains(out, `leaf = "workspaces"`) {
		t.Fatalf("missing workspaces animation, got:\n%s", out)
	}
	if !strings.Contains(out, `"slidefade 20%"`) {
		t.Fatalf("expected default slidefade 20%% style, got:\n%s", out)
	}
	if strings.Contains(out, `slidefadevert`) {
		t.Fatalf("unexpected slidefadevert with no WorkspaceStyle, got:\n%s", out)
	}
}

func TestLuaAppearanceWorkspaceStyleOverride(t *testing.T) {
	gen := NewLuaGenerator()
	vert := "slidefadevert 20%"
	enabled := true
	out := gen.GenerateAppearanceLua(ipc.ConfigAppearance{
		Animations: &ipc.Animations{
			Enabled:        &enabled,
			WorkspaceStyle: &vert,
		},
	})
	if !strings.Contains(out, `"slidefadevert 20%"`) {
		t.Fatalf("expected slidefadevert 20%% override, got:\n%s", out)
	}
	if strings.Contains(out, `"slidefade 20%"`) {
		t.Fatalf("default slidefade leaked through with override set, got:\n%s", out)
	}
}

func TestLuaAppearanceWorkspaceStyleEmptyFallsBack(t *testing.T) {
	gen := NewLuaGenerator()
	empty := ""
	enabled := true
	out := gen.GenerateAppearanceLua(ipc.ConfigAppearance{
		Animations: &ipc.Animations{
			Enabled:        &enabled,
			WorkspaceStyle: &empty,
		},
	})
	if !strings.Contains(out, `"slidefade 20%"`) {
		t.Fatalf("empty WorkspaceStyle should fall back to default, got:\n%s", out)
	}
}

func TestLuaKeybindsModifierSelfUsesReleaseFlag(t *testing.T) {
	gen := &LuaGenerator{}
	out := gen.GenerateKeybindsLua(ipc.ConfigKeybinds{
		Custom: []ipc.Keybind{
			{Modifiers: []string{"SUPER"}, Key: "Super_L", Dispatcher: "exec", Argument: "yozakura run launcher", Enabled: true},
			{Modifiers: []string{"SUPER"}, Key: "Q", Dispatcher: "exec", Argument: "kitty", Enabled: true},
		},
	})
	if !strings.Contains(out, `hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("yozakura run launcher"), { release = true })`) {
		t.Fatalf("modifier-self bind should use the release flag, got: %s", out)
	}
	if !strings.Contains(out, `hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))`) {
		t.Fatalf("ordinary bind should be kept, got: %s", out)
	}
	if strings.Contains(out, "keymon") {
		t.Fatalf("modifier-self binds are compositor-native now, got: %s", out)
	}
}

func TestLuaWindowRuleWorkspaceAndMatchProp(t *testing.T) {
	ws := "special:Telegram silent"
	out := NewLuaGenerator().GenerateWindowRulesLua([]ipc.WindowRule{
		{Match: "class:^(org.telegram.desktop)$", Workspace: &ws},
		{Match: "^(kitty)$", Rule: "x"},
	})
	for _, want := range []string{
		`match = { class = "^(org.telegram.desktop)$" },`,
		`workspace = "special:Telegram silent",`,
		`match = { class = "^(kitty)$" },`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q in:\n%s", want, out)
		}
	}
}

func TestLuaSilentMoveDoesNotFollow(t *testing.T) {
	got := dispatcherToLua("movetoworkspacesilent", "special:Dev")
	want := `hl.dsp.window.move({ workspace = "special:Dev", follow = false })`
	if got != want {
		t.Fatalf("got %s, want %s", got, want)
	}
}

func TestLuaFullscreenTogglesByMode(t *testing.T) {
	cases := map[string]string{
		"0": `hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })`,
		"1": `hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`,
		"":  `hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })`,
	}
	for arg, want := range cases {
		if got := dispatcherToLua("fullscreen", arg); got != want {
			t.Fatalf("arg %q: got %s, want %s", arg, got, want)
		}
	}
}

// A workspace switch must close the special workspace open on the monitor
// (otherwise the regular workspace changes behind the still-visible
// special). Hyprland's changeworkspace honours
// binds:hide_special_on_workspace_change, which defaults to false, so the
// keybinds section always turns it on, whatever binds are configured.
func TestGenerateKeybindsLuaHidesSpecialOnWorkspaceChange(t *testing.T) {
	const opt = "hl.config({ binds = { hide_special_on_workspace_change = true } })"
	cases := []struct {
		name string
		cfg  ipc.ConfigKeybinds
	}{
		{"empty", ipc.ConfigKeybinds{}},
		{"custom binds", ipc.ConfigKeybinds{Custom: []ipc.Keybind{
			{Modifiers: []string{"SUPER"}, Key: "2", Dispatcher: "workspace", Argument: "2", Enabled: true},
			{Modifiers: []string{"SUPER"}, Key: "S", Dispatcher: "togglespecialworkspace", Argument: "Telegram", Enabled: true},
		}}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			out := NewLuaGenerator().GenerateKeybindsLua(tc.cfg)
			if n := strings.Count(out, opt); n != 1 {
				t.Fatalf("want the option exactly once, got %d in:\n%s", n, out)
			}
		})
	}
}

// Switching and moving keep their plain dispatchers: the option above does
// the hiding inside changeworkspace, and window moves out of a special
// (movetoworkspace / silent) must not open or toggle any special.
func TestDispatcherToLuaWorkspaceSwitchAndMove(t *testing.T) {
	cases := []struct {
		dispatcher, arg, want string
	}{
		{"workspace", "2", `hl.dsp.focus({ workspace = "2" })`},
		{"workspace", "r+1", `hl.dsp.focus({ workspace = "r+1" })`},
		{"workspace", "e-1", `hl.dsp.focus({ workspace = "e-1" })`},
		{"movetoworkspace", "3", `hl.dsp.window.move({ workspace = "3" })`},
		{"movetoworkspacesilent", "3", `hl.dsp.window.move({ workspace = "3", follow = false })`},
		{"movetoworkspacesilent", "special:Telegram", `hl.dsp.window.move({ workspace = "special:Telegram", follow = false })`},
		{"togglespecialworkspace", "Telegram", `hl.dsp.workspace.toggle_special("Telegram")`},
	}
	for _, tc := range cases {
		if got := dispatcherToLua(tc.dispatcher, tc.arg); got != tc.want {
			t.Errorf("dispatcherToLua(%q, %q) = %q, want %q", tc.dispatcher, tc.arg, got, tc.want)
		}
	}
}
