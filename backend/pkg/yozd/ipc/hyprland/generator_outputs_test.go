package hyprland

import (
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

var testMonitors = []ipc.OutputConfig{
	{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1, VRR: 0},
	{Name: "HDMI-A-1", Enabled: false},
	{Name: "bad name;", Enabled: true},
}

var testKeyboard = &ipc.KeyboardSettings{
	Layouts: []string{"us", "ru"}, Variants: []string{"", ""},
	Options: []string{"grp:alt_shift_toggle", "caps:escape"}, RepeatRate: 25, RepeatDelay: 600,
}

func TestGenerateOutputsConf(t *testing.T) {
	g := NewGenerator()
	want := "monitor = DP-1,2560x1440@240,0x0,1,transform,0,vrr,0\nmonitor = HDMI-A-1,disable\n"
	if got := g.GenerateOutputs(testMonitors); got != want {
		t.Fatalf("got %q", got)
	}
	if g.GenerateOutputs(nil) != "" {
		t.Fatal("empty list must give empty output")
	}
}

func TestGenerateKeyboardConf(t *testing.T) {
	g := NewGenerator()
	want := "input {\n    kb_layout = us,ru\n    kb_variant = ,\n    kb_options = grp:alt_shift_toggle,caps:escape\n    repeat_rate = 25\n    repeat_delay = 600\n}\n"
	if got := g.GenerateKeyboard(testKeyboard); got != want {
		t.Fatalf("got %q", got)
	}
	if g.GenerateKeyboard(nil) != "" {
		t.Fatal("nil keyboard must give empty output")
	}
}

func TestGenerateOutputsLua(t *testing.T) {
	g := NewLuaGenerator()
	want := `hl.monitor({ output = "DP-1", mode = "2560x1440@240", position = "0x0", scale = 1, transform = 0, vrr = 0 })` + "\n" +
		`hl.monitor({ output = "HDMI-A-1", disabled = true })` + "\n"
	if got := g.GenerateOutputsLua(testMonitors); got != want {
		t.Fatalf("got %q", got)
	}
	if g.GenerateOutputsLua(nil) != "" {
		t.Fatal("empty list must give empty output")
	}
}

func TestGenerateKeyboardLua(t *testing.T) {
	g := NewLuaGenerator()
	want := `hl.config({ input = { kb_layout = "us,ru", kb_variant = ",", kb_options = "grp:alt_shift_toggle,caps:escape", repeat_rate = 25, repeat_delay = 600 } })` + "\n"
	if got := g.GenerateKeyboardLua(testKeyboard); got != want {
		t.Fatalf("got %q", got)
	}
	if g.GenerateKeyboardLua(nil) != "" {
		t.Fatal("nil keyboard must give empty output")
	}
}
