package hyprland

import (
	"os"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestBuildHyprKeyboardCmdsLua(t *testing.T) {
	s := ipc.KeyboardSettings{Layouts: []string{"us", "ru"}, Options: []string{"grp:alt_shift_toggle"}, RepeatRate: 25, RepeatDelay: 600}.Normalize()
	want := []string{`eval hl.config({ input = { kb_layout = "us,ru", kb_variant = ",", kb_options = "grp:alt_shift_toggle", repeat_rate = 25, repeat_delay = 600 } })`}
	if got := buildHyprKeyboardCmds(s, true); !reflect.DeepEqual(got, want) {
		t.Fatalf("%q", got)
	}
	s.RepeatRate, s.RepeatDelay = 0, 0
	want = []string{`eval hl.config({ input = { kb_layout = "us,ru", kb_variant = ",", kb_options = "grp:alt_shift_toggle" } })`}
	if got := buildHyprKeyboardCmds(s, true); !reflect.DeepEqual(got, want) {
		t.Fatalf("%q", got)
	}
}

func TestBuildHyprKeyboardCmdsLegacy(t *testing.T) {
	s := ipc.KeyboardSettings{Layouts: []string{"us", "ru"}, Variants: []string{"", "phonetic"}, RepeatRate: 30}.Normalize()
	want := []string{
		"keyword input:kb_layout us,ru",
		"keyword input:kb_variant ,phonetic",
		"keyword input:kb_options ",
		"keyword input:repeat_rate 30",
	}
	if got := buildHyprKeyboardCmds(s, false); !reflect.DeepEqual(got, want) {
		t.Fatalf("%q", got)
	}
}

func TestParseHyprActiveLayout(t *testing.T) {
	b, err := os.ReadFile("testdata/devices_keyboards.json")
	if err != nil {
		t.Fatal(err)
	}
	st, err := parseHyprActiveLayout(b)
	if err != nil {
		t.Fatal(err)
	}
	if st.Name != "Russian" || !reflect.DeepEqual(st.Names, []string{"us", "ru"}) {
		t.Fatalf("%+v", st)
	}
	if _, err := parseHyprActiveLayout([]byte(`{"keyboards":[]}`)); err == nil {
		t.Fatal("expected error")
	}
}

func TestParseActiveLayoutEvent(t *testing.T) {
	p, ok := parseActiveLayoutEvent("arbiter-keyboard,Russian")
	if !ok || p["name"] != "Russian" {
		t.Fatalf("%v %v", p, ok)
	}
	if p, _ := parseActiveLayoutEvent("kbd,English (US, intl.)"); p["name"] != "English (US, intl.)" {
		t.Fatalf("%v", p)
	}
	if _, ok := parseActiveLayoutEvent("nocomma"); ok {
		t.Fatal("accepted")
	}
}

func TestApplyKeyboardRejectsInjection(t *testing.T) {
	h := &Hyprland{}
	if err := h.ApplyKeyboard(ipc.KeyboardSettings{Layouts: []string{`us"}}); os.exit() --`}}); err == nil {
		t.Fatal("accepted injection")
	}
}
