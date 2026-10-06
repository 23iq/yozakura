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
		{KindSystem, "resolving dependencies...", -1, "resolving dependencies", true},
		{KindSystem, "Packages (1) firefox-131.0-1", -1, "", false},
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
		"Error executing command as another user: Request dismissed":  ReasonAuthCancelled,
		"Error executing command as another user: Not authorized":     ReasonAuthCancelled,
		// a stale database: the mirror no longer has that version
		"error: failed retrieving file 'x-1-1.pkg.tar.zst' from mirror : The requested URL returned error: 404": ReasonNeedsSync,
		"error: x: signature from \"y\" is invalid":                                                             "",
		"error: x-1-1.pkg.tar.zst: invalid or corrupted package (checksum)":                                     ReasonNeedsSync,
		"Error executing command as another user: No authentication agent found.":                               ReasonNoAuthAgent,
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
	if r := exitReason(pk, 127, ""); r != ReasonAuthCancelled {
		t.Errorf("127 = %q", r)
	}
	if r := exitReason([]string{"paru"}, 1, ReasonAuthCancelled); r != ReasonAuthCancelled {
		t.Errorf("paru dismissed = %q", r)
	}
	if r := exitReason([]string{"npm"}, 127, ""); r != ReasonError {
		t.Errorf("npm 127 = %q", r)
	}
	if r := exitReason(pk, 1, ReasonNeedsSync); r != ReasonNeedsSync {
		t.Errorf("seen = %q", r)
	}
}

// pacmanPiped is real `pacman -S --needed --noconfirm` output under a pipe
// (LC_ALL=C, no tty: no progress bars).
var pacmanPiped = []struct {
	line  string
	phase string
	ok    bool
}{
	{"resolving dependencies...", "resolving dependencies", true},
	{"looking for conflicting packages...", "looking for conflicting packages", true},
	{"", "", false},
	{"Packages (3) mailcap-2.1.54-1  firefox-131.0-1  telegram-desktop-5.6.1-1", "", false},
	{"Total Download Size:   75.20 MiB", "", false},
	{":: Proceed with installation? [Y/n] ", "Proceed with installation? [Y/n]", true},
	{":: Retrieving packages...", "Retrieving packages...", true},
	{" firefox-131.0-1-x86_64 downloading...", "downloading firefox-131.0-1-x86_64", true},
	{"checking keyring...", "checking keyring", true},
	{"checking package integrity...", "checking package integrity", true},
	{":: Processing package changes...", "Processing package changes...", true},
	{"installing mailcap...", "installing mailcap", true},
	{"installing firefox...", "installing firefox", true},
	{"upgrading telegram-desktop...", "upgrading telegram-desktop", true},
	{"Optional dependencies for firefox", "", false},
	{"    hunspell-en_US: Spell checking, American English", "", false},
	{":: Running post-transaction hooks...", "Running post-transaction hooks...", true},
	{"(1/3) Arming ConditionNeedsUpdate...", "Arming ConditionNeedsUpdate...", true},
}

func TestParseLinePacmanPiped(t *testing.T) {
	for _, c := range pacmanPiped {
		_, phase, ok := ParseLine(KindSystem, c.line)
		if phase != c.phase || ok != c.ok {
			t.Errorf("ParseLine(%q) = %q %v, want %q %v", c.line, phase, ok, c.phase, c.ok)
		}
	}
	pkgs := []string{"firefox", "telegram-desktop"}
	for phase, want := range map[string]int{
		"installing firefox": 0, "upgrading telegram-desktop": 50, "installing mailcap": -1, "checking keyring": -1,
	} {
		if got := pkgPercent(phase, pkgs); got != want {
			t.Errorf("pkgPercent(%q) = %d, want %d", phase, got, want)
		}
	}
}
