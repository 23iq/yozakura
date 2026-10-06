package mango

import (
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestGenerateOutputsMango(t *testing.T) {
	g := NewGenerator()
	got := g.GenerateOutputs([]ipc.OutputConfig{
		{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1, VRR: 2, Transform: 1},
		{Name: "HDMI-A-1", Enabled: false},
		{Name: "eDP.1", Enabled: true, AutoPosition: true},
		{Name: "bad;name", Enabled: true},
	})
	want := "monitor_rule=name:^DP-1$,width:2560,height:1440,refresh:240,x:0,y:0,scale:1,vrr:1,rr:1\n" +
		"monitor_rule=name:^HDMI-A-1$,disable:1\n" +
		"monitor_rule=name:^eDP\\.1$,vrr:0,rr:0\n"
	if got != want {
		t.Fatalf("got:\n%s", got)
	}
	if g.GenerateOutputs(nil) != "" {
		t.Fatal("empty list must give empty output")
	}
}

func TestGenerateKeyboardMango(t *testing.T) {
	g := NewGenerator()
	got := g.GenerateKeyboard(&ipc.KeyboardSettings{
		Layouts: []string{"us", "ru"}, Variants: []string{"", ""},
		Options: []string{"grp:alt_shift_toggle"}, Model: "pc105", RepeatRate: 25, RepeatDelay: 600,
	})
	want := "xkb_rules_layout=us,ru\nxkb_rules_variant=,\nxkb_rules_options=grp:alt_shift_toggle\nxkb_rules_model=pc105\nrepeat_rate=25\nrepeat_delay=600\n"
	if got != want {
		t.Fatalf("got:\n%s", got)
	}
	if g.GenerateKeyboard(nil) != "" {
		t.Fatal("nil keyboard must give empty output")
	}
}
