package hyprland

import "testing"

func TestParseBinds(t *testing.T) {
	data := `[
	{"modmask":76,"key":"Slash","dispatcher":"__lua","arg":"10","has_description":true,"description":"Keybinding settings","submap":""},
	{"modmask":64,"key":"Q","dispatcher":"killactive","arg":"","has_description":false,"description":"","submap":"","locked":true},
	{"modmask":0,"key":"mouse:272","dispatcher":"movewindow","has_description":false,"submap":"resize","mouse":true}]`
	binds, err := ParseBinds([]byte(data))
	if err != nil {
		t.Fatal(err)
	}
	if len(binds) != 3 {
		t.Fatalf("got %d binds", len(binds))
	}
	b := binds[0]
	if b.Key != "Slash" || len(b.Modifiers) != 3 || b.Modifiers[0] != "SUPER" || b.Modifiers[1] != "CTRL" || b.Modifiers[2] != "ALT" {
		t.Fatalf("bind 0: %+v", b)
	}
	if b.Description != "Keybinding settings" || b.Source != "ipc" {
		t.Fatalf("bind 0 description/source: %+v", b)
	}
	if binds[1].Description != "" || !binds[1].Locked || binds[1].Dispatcher != "killactive" {
		t.Fatalf("bind 1: %+v", binds[1])
	}
	if binds[2].Submap != "resize" || !binds[2].Mouse || len(binds[2].Modifiers) != 0 {
		t.Fatalf("bind 2: %+v", binds[2])
	}
	if _, err := ParseBinds([]byte("unknown request")); err == nil {
		t.Fatal("want an error for a non-JSON reply")
	}
}
