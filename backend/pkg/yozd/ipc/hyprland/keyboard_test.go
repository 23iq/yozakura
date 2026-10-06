package hyprland

import (
	"os"
	"reflect"
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestBuildHyprKeyboardCmdsLua(t *testing.T) {
	s := ipc.KeyboardSettings{Layouts: []string{"us", "ru"}, Options: []string{"grp:alt_shift_toggle"}, RepeatRate: 25, RepeatDelay: 600}.Normalize()
	want := []string{`eval hl.config({ input = { kb_layout = "us,ru", kb_variant = ",", kb_options = "grp:alt_shift_toggle", repeat_rate = 25, repeat_delay = 600 } })`}
	if got := buildHyprKeyboardCmds(s, true, true); !reflect.DeepEqual(got, want) {
		t.Fatalf("%q", got)
	}
	s.RepeatRate, s.RepeatDelay = 0, 0
	want = []string{`eval hl.config({ input = { kb_layout = "us,ru", kb_variant = ",", kb_options = "grp:alt_shift_toggle" } })`}
	if got := buildHyprKeyboardCmds(s, true, true); !reflect.DeepEqual(got, want) {
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
	if got := buildHyprKeyboardCmds(s, false, true); !reflect.DeepEqual(got, want) {
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

func TestBuildHyprKeyboardCmdsModelLua(t *testing.T) {
	s := ipc.KeyboardSettings{Layouts: []string{"us"}, Model: "pc105"}.Normalize()
	want := []string{`eval hl.config({ input = { kb_layout = "us", kb_variant = "", kb_options = "", kb_model = "pc105" } })`}
	if got := buildHyprKeyboardCmds(s, true, true); !reflect.DeepEqual(got, want) {
		t.Fatalf("%q", got)
	}
}

func TestSetKeyboardLayoutsLeavesOptionsAlone(t *testing.T) {
	s := ipc.KeyboardSettings{Layouts: []string{"us", "ru"}, Options: []string{"caps:escape"}, RepeatRate: 25}.Normalize()
	for _, lua := range []bool{true, false} {
		for _, c := range buildHyprKeyboardCmds(s, lua, false) {
			if strings.Contains(c, "kb_options") || strings.Contains(c, "repeat") || strings.Contains(c, "kb_model") {
				t.Fatalf("partial apply touched other settings: %q", c)
			}
		}
	}
	if got := buildHyprKeyboardCmds(s, true, false); got[0] != `eval hl.config({ input = { kb_layout = "us,ru", kb_variant = "," } })` {
		t.Fatalf("%q", got)
	}
}

// Replies as Hyprland 0.56 prints them (`hyprctl getoption input:... -j`).
var hyprCurrentReplies = map[string]string{
	"j/getoption input:kb_layout":    `{"option": "input:kb_layout", "str": "us,ru", "set": true }`,
	"j/getoption input:kb_variant":   `{"option": "input:kb_variant", "str": ",", "set": true }`,
	"j/getoption input:kb_options":   `{"option": "input:kb_options", "str": "grp:alt_shift_toggle", "set": true }`,
	"j/getoption input:kb_model":     `{"option": "input:kb_model", "str": "[[EMPTY]]", "set": false }`,
	"j/getoption input:repeat_rate":  `{"option": "input:repeat_rate", "int": 111, "set": true }`,
	"j/getoption input:repeat_delay": `{"option": "input:repeat_delay", "int": 175, "set": true }`,
}

func TestCurrentKeyboardFromGetoption(t *testing.T) {
	replies := map[string][]byte{}
	for k, v := range hyprCurrentReplies {
		replies[strings.TrimPrefix(k, "j/getoption input:")] = []byte(v)
	}
	got, err := currentKeyboardFrom(replies)
	if err != nil {
		t.Fatal(err)
	}
	want := ipc.KeyboardSettings{
		Layouts: []string{"us", "ru"}, Variants: []string{"", ""},
		Options: []string{"grp:alt_shift_toggle"}, RepeatRate: 111, RepeatDelay: 175,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v, want %+v", got, want)
	}
	if _, err := currentKeyboardFrom(map[string][]byte{"kb_layout": []byte("nope")}); err == nil {
		t.Fatal("garbage reply must fail")
	}
	empty, err := currentKeyboardFrom(map[string][]byte{"kb_layout": []byte(`{"str":"[[EMPTY]]"}`)})
	if err != nil || len(empty.Layouts) != 0 {
		t.Fatalf("empty layout: %+v %v", empty, err)
	}
}

func TestCurrentKeyboardQueriesHyprland(t *testing.T) {
	commands := runFakeHyprlandSocketWith(t, nil, hyprCurrentReplies)
	h := &Hyprland{signature: "test"}
	got, err := h.CurrentKeyboard()
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(got.Layouts, ",") != "us,ru" || got.RepeatRate != 111 || got.RepeatDelay != 175 {
		t.Fatalf("got %+v", got)
	}
	for _, c := range commands() {
		if !strings.HasPrefix(c, "j/getoption input:") {
			t.Fatalf("CurrentKeyboard must only read, sent %q", c)
		}
	}
}
