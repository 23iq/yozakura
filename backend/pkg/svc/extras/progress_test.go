package extras

import "testing"

func TestParseLine(t *testing.T) {
	cases := []struct {
		kind  JobKind
		line  string
		pct   int
		phase string
		ok    bool
	}{
		{KindSystem, "( 3/12) installing firefox", 25, "installing firefox", true},
		{KindSystem, "(12/12) installing ollama-cuda   [#####] 100%", 100, "installing ollama-cuda", true},
		{KindSystem, ":: Retrieving packages...", -1, "Retrieving packages...", true},
		{KindSystem, " firefox-131.0-1-x86_64 downloading...  45%", 45, "firefox-131.0-1-x86_64 downloading...", true},
		{KindSystem, "  Installing       : firefox-131.0-1.fc41.x86_64      3/12", 25, "installing firefox-131.0-1.fc41.x86_64", true},
		{KindSystem, "resolving dependencies...", -1, "", false},
		{KindAUR, "( 1/2) installing zen-browser-bin", 50, "installing zen-browser-bin", true},
		{KindFlatpak, "Installing 2/3… 47%", 49, "Installing 2/3", true},
		{KindFlatpak, "Installing 1/1...", 100, "Installing 1/1", true},
		{KindFlatpak, "Looking for matches…", -1, "", false},
		{KindNpm, "added 12 packages in 3s", 100, "added 12 packages in 3s", true},
		{KindNpm, "npm warn deprecated foo", -1, "", false},
		{KindScript, "  Downloading claude...  ", -1, "Downloading claude...", true},
		{KindShell, "building whisper.cpp", -1, "building whisper.cpp", true},
		{KindShell, "   ", -1, "", false},
	}
	for _, c := range cases {
		pct, phase, ok := ParseLine(c.kind, c.line)
		if pct != c.pct || phase != c.phase || ok != c.ok {
			t.Errorf("ParseLine(%s, %q) = %d %q %v, want %d %q %v", c.kind, c.line, pct, phase, ok, c.pct, c.phase, c.ok)
		}
	}
}

func TestFailureReasons(t *testing.T) {
	lines := map[string]string{
		"error: target not found: steam":                              ReasonNeedsSync,
		"curl: (6) Could not resolve host: claude.ai":                 ReasonNetwork,
		"error: Failed to connect to flathub":                         ReasonNetwork,
		"error: failed retrieving file 'x.pkg.tar.zst' from m":        ReasonNetwork,
		"error: failed to init transaction (unable to lock database)": ReasonDBLocked,
		"write: No space left on device":                              ReasonDiskFull,
		"installing firefox":                                          "",
	}
	for l, want := range lines {
		if got := lineReason(l); got != want {
			t.Errorf("lineReason(%q) = %q, want %q", l, got, want)
		}
	}
	pk := []string{"pkexec", "/usr/bin/yozakura", "sys", "install", "x"}
	if r := exitReason(pk, 126, ""); r != ReasonAuthCancelled {
		t.Errorf("126 = %q", r)
	}
	if r := exitReason(pk, 127, ReasonNetwork); r != ReasonAuthCancelled {
		t.Errorf("127 = %q", r)
	}
	if r := exitReason([]string{"npm"}, 127, ""); r != ReasonError {
		t.Errorf("npm 127 = %q", r)
	}
	if r := exitReason(pk, 1, ReasonNeedsSync); r != ReasonNeedsSync {
		t.Errorf("seen = %q", r)
	}
}
