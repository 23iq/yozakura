package agents

import (
	"sync"
	"sync/atomic"
)

// PermissionHook lets another service (tasks) answer a permission request
// before the configured Policy: it returns DecisionAllow or DecisionDeny,
// or "" to fall through to the policy and the user. It is called with the
// manager lock held: it must be fast and must not call back into the
// Manager.
type PermissionHook func(meta SessionMeta, req PermissionRequest) string

// hooks are the extension points other backend services attach to.
type hooks struct {
	listeners atomic.Pointer[[]func(service string, data any)]
	permMu    sync.RWMutex
	perm      PermissionHook
}

// AddListener registers fn to receive every broadcast (service, data), the
// same stream IPC subscribers get ("agents.event" with an Event,
// "agents.sessions" with []SessionMeta, ...). fn may be called with the
// manager lock held: it must not block or call back into the Manager.
func (m *Manager) AddListener(fn func(service string, data any)) {
	for {
		old := m.hooks.listeners.Load()
		var next []func(string, any)
		if old != nil {
			next = append(next, *old...)
		}
		next = append(next, fn)
		if m.hooks.listeners.CompareAndSwap(old, &next) {
			return
		}
	}
}

// SetPermissionHook installs (or clears with nil) the permission hook.
func (m *Manager) SetPermissionHook(h PermissionHook) {
	m.hooks.permMu.Lock()
	m.hooks.perm = h
	m.hooks.permMu.Unlock()
}

func (m *Manager) hookDecision(meta SessionMeta, req PermissionRequest) string {
	m.hooks.permMu.RLock()
	h := m.hooks.perm
	m.hooks.permMu.RUnlock()
	if h == nil {
		return ""
	}
	switch d := h(meta, req); d {
	case DecisionAllow, DecisionDeny:
		return d
	}
	return ""
}

// autoDecision is what a permission_resolved event reports for an
// automatic answer: "auto" when it ran, "deny" when it was refused.
func autoDecision(d string) string {
	if d == DecisionDeny {
		return DecisionDeny
	}
	return DecisionAuto
}

// withListeners wraps the IPC fan-out so registered listeners see it too.
func (m *Manager) withListeners(fn func(string, any)) func(string, any) {
	return func(service string, data any) {
		fn(service, data)
		if ls := m.hooks.listeners.Load(); ls != nil {
			for _, l := range *ls {
				l(service, data)
			}
		}
	}
}
