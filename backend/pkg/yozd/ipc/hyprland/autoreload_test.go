package hyprland

import (
	"strings"
	"testing"
	"time"
)

func fastAutoreload(t *testing.T) {
	t.Helper()
	old := autoreloadQuiet
	autoreloadQuiet = 20 * time.Millisecond
	t.Cleanup(func() { autoreloadQuiet = old })
}

func autoreloadCmds(cmds []string) []string {
	var out []string
	for _, c := range cmds {
		if strings.Contains(c, "disable_autoreload") {
			out = append(out, c)
		}
	}
	return out
}

func TestSuppressAutoreloadTurnsItOffAndBack(t *testing.T) {
	fastAutoreload(t)
	commands := runFakeHyprlandSocketWith(t, []string{`{"version":"0.54.0"}`}, map[string]string{
		"j/getoption misc:disable_autoreload": `{"option": "misc:disable_autoreload", "int": 0, "set": false}`,
	})
	h := &Hyprland{signature: "test"}
	release := h.SuppressAutoreload()
	// A second live write inside the window extends it, no second read.
	release2 := h.SuppressAutoreload()
	release()
	release2()
	time.Sleep(150 * time.Millisecond)
	got := autoreloadCmds(commands())
	want := []string{
		"j/getoption misc:disable_autoreload",
		"keyword misc:disable_autoreload 1",
		"keyword misc:disable_autoreload 1",
		"keyword misc:disable_autoreload 0",
	}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Fatalf("commands = %q, want %q", got, want)
	}
}

func TestSuppressAutoreloadLuaUsesEval(t *testing.T) {
	fastAutoreload(t)
	commands := runFakeHyprlandSocketWith(t, []string{`{"version":"0.56.0"}`}, map[string]string{
		"j/getoption misc:disable_autoreload": `{"option": "misc:disable_autoreload", "int": 0, "set": false}`,
	})
	h := &Hyprland{signature: "test"}
	h.SuppressAutoreload()()
	time.Sleep(150 * time.Millisecond)
	got := autoreloadCmds(commands())
	if len(got) != 3 || got[1] != "eval hl.config({ misc = { disable_autoreload = true } })" ||
		got[2] != "eval hl.config({ misc = { disable_autoreload = false } })" {
		t.Fatalf("commands = %q", got)
	}
}

func TestSuppressAutoreloadKeepsUserChoice(t *testing.T) {
	fastAutoreload(t)
	commands := runFakeHyprlandSocketWith(t, []string{`{"version":"0.54.0"}`}, map[string]string{
		"j/getoption misc:disable_autoreload": `{"option": "misc:disable_autoreload", "int": 1, "set": true}`,
	})
	h := &Hyprland{signature: "test"}
	h.SuppressAutoreload()()
	time.Sleep(100 * time.Millisecond)
	if got := autoreloadCmds(commands()); len(got) != 1 {
		t.Fatalf("autoreload already off must not be touched, sent %q", got)
	}
}
