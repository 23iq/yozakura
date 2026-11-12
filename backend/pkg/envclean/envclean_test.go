package envclean

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func TestDedupe(t *testing.T) {
	cases := []struct {
		name, in, want string
		n              int
	}{
		{"unchanged", "/a:/b", "/a:/b", 2},
		{"duplicates", "/a:/b:/a:/b:/c", "/a:/b:/c", 5},
		{"trailing slash", "/a:/a/:/b/:/b", "/a:/b/", 4},
		{"empty entries", ":/a::/b:", "/a:/b", 5},
		{"order preserved", "/z:/y:/z:/x", "/z:/y:/x", 4},
		{"root", "/:/", "/", 2},
		{"empty", "", "", 1},
	}
	for _, c := range cases {
		got, n := Dedupe(c.in)
		if got != c.want || n != c.n {
			t.Errorf("%s: got (%q,%d) want (%q,%d)", c.name, got, n, c.want, c.n)
		}
	}
}

func TestCleanLargeRepeated(t *testing.T) {
	dirs := []string{"/u/a", "/u/b", "/u/c", "/u/d"}
	in := strings.TrimSuffix(strings.Repeat(strings.Join(dirs, ":")+":", 320), ":")
	if got := strings.Count(in, ":") + 1; got != 1280 {
		t.Fatalf("setup: %d", got)
	}
	var logs []string
	env := Clean([]string{"HOME=/h", "XDG_DATA_DIRS=" + in, "FOO=/a:/a"}, func(f string, a ...any) {
		logs = append(logs, f)
	})
	if env[0] != "HOME=/h" || env[2] != "FOO=/a:/a" {
		t.Errorf("other vars touched: %v", env)
	}
	if env[1] != "XDG_DATA_DIRS=/u/a:/u/b:/u/c:/u/d" {
		t.Errorf("got %q", env[1])
	}
	if len(logs) != 1 {
		t.Errorf("logs %v", logs)
	}
}

func TestCleanLogMessage(t *testing.T) {
	var msg string
	Clean([]string{"PATH=/a:/a:/b"}, func(f string, a ...any) {
		msg = strings.TrimSpace(fmt.Sprintf(f, a...))
	})
	if msg != "env: PATH had 3 entries, kept 2" {
		t.Errorf("got %q", msg)
	}
}

func TestCleanNoChangeNoLog(t *testing.T) {
	Clean([]string{"PATH=/a:/b", "NOEQUALS"}, func(string, ...any) { t.Error("logged") })
}

func TestCleanProcess(t *testing.T) {
	t.Setenv("QML_IMPORT_PATH", "/q::/q/:/r")
	msgs := CleanProcess()
	found := false
	for _, m := range msgs {
		found = found || m == "env: QML_IMPORT_PATH had 4 entries, kept 2"
	}
	if !found {
		t.Errorf("msgs %v", msgs)
	}
	if got := os.Getenv("QML_IMPORT_PATH"); got != "/q:/r" {
		t.Errorf("got %q", got)
	}
}

func TestCleanProcessQuietWhenClean(t *testing.T) {
	for _, k := range Vars {
		t.Setenv(k, "/q:/r")
	}
	if msgs := CleanProcess(); len(msgs) != 0 {
		t.Errorf("msgs %v", msgs)
	}
}

// The role of a separate window process never reaches another child: a
// main shell or daemon started from a window's environment stays the main
// shell.
func TestWindowVarsAreDropped(t *testing.T) {
	for _, k := range WindowVars {
		t.Setenv(k, "settings")
	}
	t.Setenv("KEEP_ME", "1")
	for _, kv := range ChildEnv() {
		k, _, _ := strings.Cut(kv, "=")
		if isWindowVar(k) {
			t.Errorf("ChildEnv kept %s", kv)
		}
	}
	got := StripWindowVars([]string{"A=1", WindowVars[0] + "=settings", "B=2"})
	if strings.Join(got, ",") != "A=1,B=2" {
		t.Errorf("StripWindowVars: %v", got)
	}
	msgs := CleanProcess()
	for _, k := range WindowVars {
		if _, ok := os.LookupEnv(k); ok {
			t.Errorf("CleanProcess left %s", k)
		}
	}
	if len(msgs) < len(WindowVars) {
		t.Errorf("CleanProcess messages: %v", msgs)
	}
	if os.Getenv("KEEP_ME") != "1" {
		t.Error("other variables are kept")
	}
}
