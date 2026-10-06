package niri

import (
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestGenerateOutputsKDL(t *testing.T) {
	g := NewGenerator()
	got := g.GenerateOutputs([]ipc.OutputConfig{
		{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1, VRR: 1},
		{Name: "DP-2", Enabled: true, X: 2560, Transform: 1, VRR: 2},
		{Name: "HDMI-A-1", Enabled: false},
		{Name: "x y", Enabled: true},
	})
	want := "output \"DP-1\" {\n    mode \"2560x1440@240.000\"\n    scale 1\n    position x=0 y=0\n    transform \"normal\"\n    variable-refresh-rate\n}\n" +
		"output \"DP-2\" {\n    position x=2560 y=0\n    transform \"90\"\n    variable-refresh-rate on-demand=true\n}\n" +
		"output \"HDMI-A-1\" {\n    off\n}\n"
	if got != want {
		t.Fatalf("got:\n%s", got)
	}
	if g.GenerateOutputs(nil) != "" {
		t.Fatal("empty list must give empty output")
	}
}

func TestGenerateKeyboardKDL(t *testing.T) {
	g := NewGenerator()
	got := g.GenerateKeyboard(&ipc.KeyboardSettings{
		Layouts: []string{"us", "ru"}, Variants: []string{"", ""},
		Options: []string{"grp:alt_shift_toggle"}, Model: "pc105", RepeatRate: 25, RepeatDelay: 600,
	})
	want := "input {\n    keyboard {\n        xkb {\n            layout \"us,ru\"\n            variant \",\"\n            options \"grp:alt_shift_toggle\"\n            model \"pc105\"\n        }\n        repeat-rate 25\n        repeat-delay 600\n    }\n}\n"
	if got != want {
		t.Fatalf("got:\n%s", got)
	}
	if g.GenerateKeyboard(nil) != "" {
		t.Fatal("nil keyboard must give empty output")
	}
}
