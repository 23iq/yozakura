package apphooks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"yozakura/backend/pkg/brand"
)

// DefaultEnv is the real environment: the user's dirs, a /proc scan for
// running apps and signals sent to matching processes.
func DefaultEnv() Env {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	cfg := os.Getenv("XDG_CONFIG_HOME")
	if cfg == "" {
		cfg = filepath.Join(home, ".config")
	}
	cache := os.Getenv("XDG_CACHE_HOME")
	if cache == "" {
		cache = filepath.Join(home, ".cache")
	}
	data := os.Getenv("XDG_DATA_HOME")
	if data == "" {
		data = filepath.Join(home, ".local", "share")
	}
	return Env{
		Home: home, ConfigHome: cfg,
		CacheDir: filepath.Join(cache, brand.AppID), DataDir: filepath.Join(data, brand.AppID), AppID: brand.AppID,
		Running: func(proc string) bool { return len(pids(proc)) > 0 },
		Signal: func(proc string, sig syscall.Signal) {
			for _, pid := range pids(proc) {
				_ = syscall.Kill(pid, sig)
			}
		},
	}
}

// pids lists the processes of the current user whose command name is proc.
func pids(proc string) []int {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}
	uid := os.Getuid()
	var out []int
	for _, e := range entries {
		var pid int
		if _, err := fmt.Sscanf(e.Name(), "%d", &pid); err != nil || fmt.Sprint(pid) != e.Name() {
			continue
		}
		if st, err := os.Stat(filepath.Join("/proc", e.Name())); err != nil || !ownedBy(st, uid) {
			continue
		}
		comm, err := os.ReadFile(filepath.Join("/proc", e.Name(), "comm"))
		if err == nil && strings.TrimSpace(string(comm)) == proc {
			out = append(out, pid)
		}
	}
	return out
}

func ownedBy(st os.FileInfo, uid int) bool {
	s, ok := st.Sys().(*syscall.Stat_t)
	return ok && int(s.Uid) == uid
}

// ApplyByID connects one app; the extras installer calls it after it installs
// the app.
func ApplyByID(env Env, id string) (Status, error) {
	h, ok := Get(id)
	if !ok {
		return Status{ID: id}, fmt.Errorf("apphooks: unknown app %q", id)
	}
	return h.Apply(env)
}

// Statuses returns the status of every registered hook by id.
func Statuses(env Env) map[string]Status {
	out := map[string]Status{}
	for _, h := range All() {
		out[h.ID()] = h.Status(env)
	}
	return out
}

// Outcome is one hook's result of RevertAll.
type Outcome struct {
	Status Status
	Err    error
}

// RevertAll reverts every hook (uninstall) and returns the outcome per hook,
// in order. A failing hook does not stop the others.
func RevertAll(env Env, hooks []Hook) []Outcome {
	out := make([]Outcome, 0, len(hooks))
	for _, h := range hooks {
		st, err := h.Revert(env)
		if err != nil && st.Reason == "" {
			st.Reason = err.Error()
		}
		out = append(out, Outcome{st, err})
	}
	return out
}
