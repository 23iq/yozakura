package config

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

const monitorsTOML = `
[[monitors]]
name = "DP-1"
enabled = true
width = 2560
height = 1440
refresh = 240.0
scale = 1.0
vrr = 2

[[monitors]]
name = "HDMI-A-1"
enabled = false

[input.keyboard]
layouts = "us,ru"
variants = ","
options = "grp:alt_shift_toggle,caps:escape"
model = "pc105"
repeat_rate = 25
repeat_delay = 600
`

func TestLoadConfigMonitorsAndKeyboard(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "yozd.toml")
	if err := os.WriteFile(p, []byte(monitorsTOML), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg, err := LoadConfig(p)
	if err != nil {
		t.Fatal(err)
	}
	u := cfg.ToIPCConfig()
	if len(u.Monitors) != 2 || u.Monitors[0].Name != "DP-1" || u.Monitors[0].Width != 2560 ||
		u.Monitors[0].Refresh != 240 || u.Monitors[0].VRR != 2 || !u.Monitors[0].Enabled || u.Monitors[1].Enabled {
		t.Fatalf("monitors: %+v", u.Monitors)
	}
	k := u.Keyboard
	if k == nil || !reflect.DeepEqual(k.Layouts, []string{"us", "ru"}) || !reflect.DeepEqual(k.Variants, []string{"", ""}) ||
		!reflect.DeepEqual(k.Options, []string{"grp:alt_shift_toggle", "caps:escape"}) ||
		k.Model != "pc105" || k.RepeatRate != 25 || k.RepeatDelay != 600 {
		t.Fatalf("keyboard: %+v", k)
	}
}

func TestMergeMonitorsReplaceNotAppend(t *testing.T) {
	dst := &TOMLConfig{Monitors: []MonitorConfig{{Name: "A-1"}, {Name: "B-1"}}}
	mergeConfig(dst, &TOMLConfig{Monitors: []MonitorConfig{{Name: "C-1"}}})
	if len(dst.Monitors) != 1 || dst.Monitors[0].Name != "C-1" {
		t.Fatalf("got %+v", dst.Monitors)
	}
	mergeConfig(dst, &TOMLConfig{})
	if len(dst.Monitors) != 1 {
		t.Fatalf("empty src must not clear: %+v", dst.Monitors)
	}
}
