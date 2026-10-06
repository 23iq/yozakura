package compositor

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	yozdconfig "yozakura/backend/pkg/yozd/config"
	"yozakura/backend/pkg/yozd/ipc"
)

func TestSwitchBindOption(t *testing.T) {
	cases := map[string]string{
		"alt_shift":   "grp:alt_shift_toggle",
		"super_space": "grp:win_space_toggle",
		"caps":        "grp:caps_toggle",
		"ctrl_shift":  "grp:ctrl_shift_toggle",
		"none":        "",
		"":            "",
		"bogus":       "",
	}
	for in, want := range cases {
		if got := SwitchBindOption(in); got != want {
			t.Errorf("SwitchBindOption(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestKeyboardInputSettings(t *testing.T) {
	k := KeyboardInput{
		Layouts:     []KeyboardLayout{{Layout: "us"}, {Layout: "ru", Variant: "phonetic"}, {Layout: " "}},
		SwitchBind:  "alt_shift",
		Options:     []string{"caps:escape", "grp:alt_shift_toggle", "bad option"},
		RepeatRate:  25,
		RepeatDelay: 600,
	}
	got := k.Settings()
	want := ipc.KeyboardSettings{
		Layouts:     []string{"us", "ru"},
		Variants:    []string{"", "phonetic"},
		Options:     []string{"grp:alt_shift_toggle", "caps:escape"},
		RepeatRate:  25,
		RepeatDelay: 600,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Settings() = %+v, want %+v", got, want)
	}
}

func devicesInput() Input {
	return Input{
		Displays: []DisplayInput{
			{ID: "Dell|U2720Q|ABC", Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1},
			{Name: "HDMI-A-1", Enabled: false, AutoPosition: true},
			{Name: "bad name;rm", Enabled: true},
		},
		Keyboard: &KeyboardInput{
			Layouts:     []KeyboardLayout{{Layout: "us"}, {Layout: "ru"}},
			SwitchBind:  "alt_shift",
			Options:     []string{"caps:escape"},
			RepeatRate:  25,
			RepeatDelay: 600,
		},
	}
}

func TestRenderDisplaysAndKeyboardGolden(t *testing.T) {
	out := Render(devicesInput(), false)
	want := `
[[monitors]]
name = "DP-1"
enabled = true
width = 2560
height = 1440
refresh = 240.0
x = 0
y = 0
auto_position = false
scale = 1.0
transform = 0
vrr = 0

[[monitors]]
name = "HDMI-A-1"
enabled = false
width = 0
height = 0
refresh = 0.0
x = 0
y = 0
auto_position = true
scale = 0.0
transform = 0
vrr = 0

[input]
[input.keyboard]
layouts = "us,ru"
variants = ","
options = "grp:alt_shift_toggle,caps:escape"
model = ""
repeat_rate = 25
repeat_delay = 600
`
	if !strings.HasSuffix(out, want) {
		t.Fatalf("rendered TOML tail mismatch.\n--- got ---\n%s\n--- want suffix ---\n%s", out, want)
	}
	if strings.Contains(out, "bad name") {
		t.Fatal("invalid connector name must not be rendered")
	}
}

// The rendered sections must load through yozd's own TOML loader.
func TestRenderDisplaysLoadsInYozd(t *testing.T) {
	path := filepath.Join(t.TempDir(), "yozd.toml")
	if err := os.WriteFile(path, []byte(Render(devicesInput(), false)), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg, err := yozdconfig.LoadConfig(path)
	if err != nil {
		t.Fatalf("yozd LoadConfig: %v", err)
	}
	u := cfg.ToIPCConfig()
	if len(u.Monitors) != 2 || u.Monitors[0].Name != "DP-1" || u.Monitors[0].Refresh != 240 || u.Monitors[0].Scale != 1 {
		t.Fatalf("monitors = %+v", u.Monitors)
	}
	if u.Monitors[1].Enabled || !u.Monitors[1].AutoPosition {
		t.Fatalf("second monitor = %+v", u.Monitors[1])
	}
	if u.Keyboard == nil || strings.Join(u.Keyboard.Layouts, ",") != "us,ru" ||
		strings.Join(u.Keyboard.Options, ",") != "grp:alt_shift_toggle,caps:escape" || u.Keyboard.RepeatDelay != 600 {
		t.Fatalf("keyboard = %+v", u.Keyboard)
	}
}

func TestRenderWithoutKeyboardKeepsEmptyLayouts(t *testing.T) {
	out := Render(Input{}, false)
	if !strings.HasSuffix(out, "[input]\n[input.keyboard]\nlayouts = \"\"\nvariants = \"\"\n") {
		t.Fatalf("unexpected tail:\n%s", out)
	}
	if strings.Contains(out, "[[monitors]]") {
		t.Fatal("no displays must render no [[monitors]]")
	}
}
