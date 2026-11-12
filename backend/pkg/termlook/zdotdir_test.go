package termlook

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func fakeZsh(t *testing.T, body string) func(string) (string, bool) {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "zsh")
	writeFile(t, bin, "#!/bin/sh\n"+body)
	if err := os.Chmod(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	return func(b string) (string, bool) { return bin, b == "zsh" }
}

// zsh is asked (it reads ~/.zshenv, the daemon did not): its answer wins
// over this process's environment, output of the user's zshenv is skipped
// and the answer is cached.
func TestZshDotDirAsksZsh(t *testing.T) {
	home := t.TempDir()
	t.Setenv("ZDOTDIR", "")
	calls := filepath.Join(home, "calls")
	look := fakeZsh(t, `echo hello from zshenv
echo x >> "$HOME/calls"
echo "zdotdir=$HOME/.config/zsh"
`)
	for range 2 {
		if got := ZshDotDir(home, look); got != filepath.Join(home, ".config", "zsh") {
			t.Fatalf("got %q", got)
		}
	}
	if n := strings.Count(readFile(t, calls), "x"); n != 1 {
		t.Errorf("zsh ran %d times", n)
	}
}

func TestZshDotDirFallsBack(t *testing.T) {
	home := t.TempDir()
	t.Setenv("ZDOTDIR", "/env/zdot")
	if got := ZshDotDir(home, func(string) (string, bool) { return "", false }); got != "/env/zdot" {
		t.Errorf("no zsh: %q", got)
	}
	t.Setenv("ZDOTDIR", "")
	if got := ZshDotDir(home, nil); got != home {
		t.Errorf("no zsh, no ZDOTDIR: %q", got)
	}
	if got := ZshDotDir(t.TempDir(), fakeZsh(t, "echo zdotdir=relative\n")); got != "" && !filepath.IsAbs(got) {
		t.Errorf("relative answer used: %q", got)
	}
	old := zdotdirBudget
	zdotdirBudget = 200 * time.Millisecond
	t.Cleanup(func() { zdotdirBudget = old })
	start := time.Now()
	h := t.TempDir()
	if got := ZshDotDir(h, fakeZsh(t, "sleep 30\n")); got != h {
		t.Errorf("hanging zsh: %q", got)
	}
	if d := time.Since(start); d > 2*time.Second {
		t.Errorf("hanging zsh took %v", d)
	}
}

// ZDOTDIR set in ~/.zshenv only: the line goes into $ZDOTDIR/.zshrc, a
// line an earlier run left in ~/.zshrc goes, and turning off (from any
// environment) cleans both.
func TestGreetingFollowsZshsOwnZDotDir(t *testing.T) {
	env := greetEnv(t)
	zdot := filepath.Join(env.Home, ".config", "zsh")
	homeRC := filepath.Join(env.Home, ".zshrc")
	cfg := GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura, LoginShell: "/usr/bin/zsh"}
	// an earlier run that did not know ZDOTDIR created ~/.zshrc
	applyGreeting(t, cfg, env)
	if !strings.Contains(readFile(t, homeRC), "greeting.sh") {
		t.Fatal("no line in ~/.zshrc")
	}
	env.ResolveZDotDir = func() string { return zdot }
	st := applyGreeting(t, cfg, env)
	if s := stateOf(st, "zsh"); s.State != ShellOn || s.File != filepath.Join(zdot, ".zshrc") {
		t.Errorf("zsh %+v", s)
	}
	if _, err := os.Stat(homeRC); err == nil {
		t.Errorf("~/.zshrc we created is left: %q", readFile(t, homeRC))
	}
	// the earlier line again (an older build), then uninstall
	applyGreeting(t, cfg, Env{Home: env.Home, ConfigHome: env.ConfigHome, AppID: env.AppID, DataHome: env.DataHome, LookPath: env.LookPath})
	if err := RemoveGreeting(env); err != nil {
		t.Fatal(err)
	}
	for _, rc := range []string{homeRC, filepath.Join(zdot, ".zshrc")} {
		if _, err := os.Stat(rc); err == nil {
			t.Errorf("%s left: %q", rc, readFile(t, rc))
		}
	}
}
