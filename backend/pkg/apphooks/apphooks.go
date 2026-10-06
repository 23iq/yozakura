// Package apphooks connects third-party apps (terminals, chat clients, ...)
// to the theme files the shell generates. Every hook is idempotent: Apply
// adds exactly what Revert removes, files the user manages elsewhere (Nix
// store, unparsable content) are never touched, and running apps are never
// killed.
package apphooks

import (
	"sort"
	"sync"
	"syscall"
)

// State describes how an app relates to the generated theme.
type State string

const (
	StateConnected    State = "connected"
	StateDisconnected State = "disconnected"
	StateAbsent       State = "absent"
	StateManaged      State = "managed"
	StateError        State = "error"
)

// Status is the outcome of Status/Apply/Revert for one app.
type Status struct {
	ID           string   `json:"id"`
	State        State    `json:"state"`
	Files        []string `json:"files,omitempty"`
	NeedsRestart bool     `json:"needsRestart,omitempty"`
	Reason       string   `json:"reason,omitempty"`
}

// Env is everything a hook needs from the outside world; tests fake it.
type Env struct {
	Home       string
	ConfigHome string
	CacheDir   string // ~/.cache/<app>
	DataDir    string // ~/.local/share/<app>: Apply/Revert bookkeeping
	AppID      string
	Running    func(proc string) bool
	Signal     func(proc string, sig syscall.Signal)
}

func (e Env) running(procs ...string) bool {
	if e.Running == nil {
		return false
	}
	for _, p := range procs {
		if e.Running(p) {
			return true
		}
	}
	return false
}

func (e Env) signal(proc string, sig syscall.Signal) {
	if e.Signal != nil {
		e.Signal(proc, sig)
	}
}

// Hook connects one app.
type Hook interface {
	ID() string
	Status(env Env) Status
	Apply(env Env) (Status, error)
	Revert(env Env) (Status, error)
}

var (
	mu    sync.RWMutex
	hooks = map[string]Hook{}
)

// Register adds a hook (replacing one with the same id).
func Register(h Hook) {
	mu.Lock()
	defer mu.Unlock()
	hooks[h.ID()] = h
}

// Get returns the hook with the given id.
func Get(id string) (Hook, bool) {
	mu.RLock()
	defer mu.RUnlock()
	h, ok := hooks[id]
	return h, ok
}

// All returns every registered hook sorted by id.
func All() []Hook {
	mu.RLock()
	defer mu.RUnlock()
	out := make([]Hook, 0, len(hooks))
	for _, h := range hooks {
		out = append(out, h)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID() < out[j].ID() })
	return out
}
