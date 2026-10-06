package exclusive

import (
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestParseKeyboardConf(t *testing.T) {
	conf := `
input {
    kb_layout = us, ru   # two layouts
    kb_variant = ,phonetic
    kb_options = grp:alt_shift_toggle,caps:escape
    repeat_rate = 35
    touchpad {
        kb_layout = ignored
    }
    repeat_delay = 250
}
device {
    name = my-keyboard
    kb_layout = de
}
general { col.active_border = rgb(ff0000) }
`
	got := parseKeyboard(strings.Split(conf, "\n"), false)
	want := map[string]string{"kb_layout": "us, ru", "kb_variant": ",phonetic",
		"kb_options": "grp:alt_shift_toggle,caps:escape", "repeat_rate": "35", "repeat_delay": "250"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v", got)
	}
	if got := parseKeyboard([]string{"input:kb_layout = fr"}, false); got["kb_layout"] != "fr" {
		t.Fatalf("input:key form: %v", got)
	}
}

func TestParseKeyboardLua(t *testing.T) {
	lua := `
local layout = "de"
hl.config({ input = { kb_layout = "us,ru", repeat_rate = 30, touchpad = { natural_scroll = true } } })
hl.config({
    input = {
        kb_options = "grp:win_space_toggle", -- switch
        kb_variant = layout,
        repeat_delay = 300,
        repeat_rate = "x",
    },
})
hl.device({ name = "kbd", kb_layout = "fr" })
-- hl.config({ input = { kb_layout = "commented" } })
`
	got := parseKeyboard(strings.Split(lua, "\n"), true)
	want := map[string]string{"kb_layout": "us,ru", "repeat_rate": "30", "kb_options": "grp:win_space_toggle", "repeat_delay": "300"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v", got)
	}
}

func TestKeyboardFrom(t *testing.T) {
	if keyboardFrom(map[string]string{}) != nil {
		t.Fatal("no keys must give nil")
	}
	kb := keyboardFrom(map[string]string{"kb_layout": "us, ru", "kb_variant": ",phonetic", "kb_options": "caps:escape,", "repeat_delay": "250"})
	if !reflect.DeepEqual(kb.Layouts, []string{"us", "ru"}) || !reflect.DeepEqual(kb.Variants, []string{"", "phonetic"}) ||
		!reflect.DeepEqual(kb.Options, []string{"caps:escape"}) || kb.RepeatDelay != 250 {
		t.Fatalf("%+v", kb)
	}
	if kb := keyboardFrom(map[string]string{"kb_layout": "$layout"}); len(kb.Layouts) != 0 {
		t.Fatalf("variables must not be imported: %+v", kb)
	}
}

func TestScanImportsSkipsInstallerBlockAndDedupes(t *testing.T) {
	home := t.TempDir()
	hypr := filepath.Join(home, ".config/hypr")
	write(t, filepath.Join(hypr, "a.conf"), "monitor = DP-1,1920x1080@60,0x0,1\nmonitor = desc:Foo,preferred,auto,1\n", 0o644)
	write(t, filepath.Join(hypr, "b.conf"), "monitor = DP-1,2560x1440@144,0x0,1\nmonitor = HDMI-A-1,disable\n", 0o644)
	mons, kb := ScanImports(hypr, filepath.Join(home, ".local/share/yozakura"))
	if kb != nil || len(mons) != 2 || mons[0].Name != "DP-1" || mons[0].Width != 2560 || mons[1].Enabled {
		t.Fatalf("%+v %+v", mons, kb)
	}
}
