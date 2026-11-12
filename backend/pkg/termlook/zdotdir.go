package termlook

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"syscall"
	"time"
)

// zsh reads .zshrc from $ZDOTDIR, which users commonly set in ~/.zshenv.
// The daemon is started by the compositor and has not read that file, so
// its own environment says nothing: zsh itself is asked (it reads its
// zshenv files first, also for -c). The command is constant and runs with
// no input, in a process group of its own, under a short timeout.

const zdotdirPrefix = "zdotdir="

var zdotdirBudget = 2 * time.Second

var zdotdirCache struct {
	sync.Mutex
	dirs map[string]string // home -> answer of zsh
}

// ZshDotDir is the directory zsh reads .zshrc from for the user whose home
// is home: what zsh prints after its startup files (cached once zsh
// answered), else $ZDOTDIR of this process, else home.
func ZshDotDir(home string, look func(string) (string, bool)) string {
	fallback := func() string {
		if d := os.Getenv("ZDOTDIR"); filepath.IsAbs(d) {
			return filepath.Clean(d)
		}
		return home
	}
	if look == nil {
		return fallback()
	}
	zsh, ok := look("zsh")
	if !ok {
		return fallback()
	}
	zdotdirCache.Lock()
	defer zdotdirCache.Unlock()
	if d, ok := zdotdirCache.dirs[home]; ok {
		return d
	}
	d := askZsh(zsh, home, false)
	if d == "" {
		return fallback()
	}
	if zdotdirCache.dirs == nil {
		zdotdirCache.dirs = map[string]string{}
	}
	zdotdirCache.dirs[home] = d
	return d
}

// ZshDotDirs are every directory a .zshrc of the greeting may be in, for
// an uninstall run from any terminal: zsh's answer in this environment
// and in one without ZDOTDIR (the daemon's), $ZDOTDIR and home.
func ZshDotDirs(home string, look func(string) (string, bool)) []string {
	dirs := []string{ZshDotDir(home, look)}
	if look != nil {
		if zsh, ok := look("zsh"); ok {
			dirs = append(dirs, askZsh(zsh, home, true))
		}
	}
	if d := os.Getenv("ZDOTDIR"); filepath.IsAbs(d) {
		dirs = append(dirs, filepath.Clean(d))
	}
	dirs = append(dirs, home)
	var out []string
	for _, d := range dirs {
		if d != "" && !slices.Contains(out, d) {
			out = append(out, d)
		}
	}
	return out
}

// askZsh runs zsh -c and reads the ZDOTDIR it ends up with ("" when it
// does not answer); clean: without the ZDOTDIR of this process.
func askZsh(zsh, home string, clean bool) string {
	ctx, cancel := context.WithTimeout(context.Background(), zdotdirBudget)
	defer cancel()
	cmd := exec.CommandContext(ctx, zsh, "-c", `print -r -- "`+zdotdirPrefix+`${ZDOTDIR:-$HOME}"`)
	var env []string
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "HOME=") && !(clean && strings.HasPrefix(kv, "ZDOTDIR=")) {
			env = append(env, kv)
		}
	}
	cmd.Env = append(env, "HOME="+home)
	cmd.Dir = home
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 200 * time.Millisecond
	out := &cappedBuffer{max: 64 << 10}
	cmd.Stdout = out
	if err := cmd.Run(); err != nil && ctx.Err() != nil {
		return ""
	}
	// a zshenv may print: the last line of ours counts
	dir := ""
	for _, line := range strings.Split(out.String(), "\n") {
		if v, ok := strings.CutPrefix(line, zdotdirPrefix); ok {
			dir = v
		}
	}
	if !filepath.IsAbs(dir) || hasControl(dir) {
		return ""
	}
	return filepath.Clean(dir)
}

// zshRCs are the .zshrc files the greeting line may be in: zsh's own
// first, then ~/.zshrc when ZDOTDIR points elsewhere (a line an earlier
// run put there before ZDOTDIR was known).
func zshRCs(env Env) []string {
	rc := filepath.Join(env.zdotdir(), ".zshrc")
	home := filepath.Join(env.Home, ".zshrc")
	if filepath.Clean(rc) == filepath.Clean(home) {
		return []string{rc}
	}
	return []string{rc, home}
}
