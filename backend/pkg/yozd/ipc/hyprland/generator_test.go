package hyprland

import (
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestGenerateLayerRulesSkipsNiriOnlyProps(t *testing.T) {
	g := &Generator{}
	yes := true
	out := g.GenerateLayerRules([]ipc.LayerRule{
		{Namespace: "^yozakura:wallpaper$", PlaceWithinBackdrop: &yes},
	})
	if strings.Contains(out, "layerrule") {
		t.Fatalf("expected no layerrule for a niri-only property, got: %s", out)
	}
}

func TestGenerateLayerRulesKnownProps(t *testing.T) {
	g := &Generator{}
	yes := true
	out := g.GenerateLayerRules([]ipc.LayerRule{
		{Namespace: "quickshell", Blur: &yes, NoAnim: &yes},
	})
	if !strings.Contains(out, "layerrule") || !strings.Contains(out, "blur on") {
		t.Fatalf("expected layerrule with blur, got: %s", out)
	}
}

func TestGenerateKeybindsModifierSelfUsesReleaseBind(t *testing.T) {
	g := &Generator{}
	out := g.GenerateKeybinds(ipc.ConfigKeybinds{
		Custom: []ipc.Keybind{
			{Modifiers: []string{"SUPER"}, Key: "Super_L", Dispatcher: "exec", Argument: "yozakura run launcher", Enabled: true},
			{Modifiers: []string{"SUPER"}, Key: "Q", Dispatcher: "exec", Argument: "kitty", Enabled: true},
		},
	})
	if !strings.Contains(out, "bindr = SUPER, Super_L, exec, yozakura run launcher") {
		t.Fatalf("modifier-self bind should be a release bind, got: %s", out)
	}
	if strings.Contains(out, "bind = SUPER, Super_L") {
		t.Fatalf("modifier-self bind must not be a plain press bind, got: %s", out)
	}
	if !strings.Contains(out, "bind = SUPER, Q, exec, kitty") {
		t.Fatalf("ordinary bind should be kept, got: %s", out)
	}
	if strings.Contains(out, "keymon") {
		t.Fatalf("modifier-self binds are compositor-native now, got: %s", out)
	}
}

func TestGenerateWindowRulesWorkspace(t *testing.T) {
	ws := "special:Discord silent"
	out := NewGenerator().GenerateWindowRules([]ipc.WindowRule{{Match: "class:^(vesktop)$", Workspace: &ws}})
	if !strings.Contains(out, "windowrule = workspace special:Discord silent, match:class vesktop") {
		t.Fatalf("unexpected rules:\n%s", out)
	}
}

func TestGenerateKeybindsHidesSpecialOnWorkspaceChange(t *testing.T) {
	for _, cfg := range []ipc.ConfigKeybinds{{}, {Custom: []ipc.Keybind{
		{Modifiers: []string{"SUPER"}, Key: "2", Dispatcher: "workspace", Argument: "2", Enabled: true},
	}}} {
		out := NewGenerator().GenerateKeybinds(cfg)
		if n := strings.Count(out, "binds {\n    hide_special_on_workspace_change = true\n}"); n != 1 {
			t.Fatalf("want the binds block exactly once, got %d in:\n%s", n, out)
		}
	}
}
