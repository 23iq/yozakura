package main

import "testing"

func TestSkipsStartupMigrations(t *testing.T) {
	cases := []struct {
		args  []string
		alive bool
		want  bool
	}{
		// the shell start always migrates
		{nil, true, false},
		{nil, false, false},
		// daemon / yozd / logind only, no config read
		{[]string{"screen", "off"}, false, true},
		{[]string{"suspend"}, false, true},
		{[]string{"brightness", "+5"}, false, true},
		{[]string{"ipc", "call", "x.y"}, false, true},
		// UI commands: the running daemon already migrated
		{[]string{"run", "launcher"}, true, true},
		{[]string{"toggle", "bar"}, true, true},
		{[]string{"lock"}, true, true},
		// no daemon: `run terminal` reads general.json, keep today's order
		{[]string{"run", "terminal"}, false, false},
		{[]string{"toggle", "bar"}, false, false},
		{[]string{"lock"}, false, false},
		// everything else keeps the migrations
		{[]string{"onboarding"}, true, false},
		{[]string{"reload"}, true, false},
		{[]string{"quit"}, true, false},
		{[]string{"wallpaper", "/x.png"}, true, false},
		{[]string{"thumbs", "a", "b"}, true, false},
		{[]string{"colorpicker"}, true, false},
		{[]string{"voice", "press", "ai"}, true, false},
		{[]string{"unknown"}, true, false},
	}
	for _, tc := range cases {
		probed := false
		alive := func() bool { probed = true; return tc.alive }
		if got := skipsStartupMigrations(tc.args, alive); got != tc.want {
			t.Errorf("skipsStartupMigrations(%q, alive=%v) = %v, want %v", tc.args, tc.alive, got, tc.want)
		}
		ui := len(tc.args) > 0 && (tc.args[0] == "run" || tc.args[0] == "toggle" || tc.args[0] == "lock")
		if probed != ui {
			t.Errorf("%q: probed the daemon = %v, want %v", tc.args, probed, ui)
		}
	}
}
