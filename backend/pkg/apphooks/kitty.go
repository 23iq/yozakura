package apphooks

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

type kittyHook struct{}

func init() { Register(kittyHook{}) }

func (kittyHook) ID() string { return "kitty" }

func (kittyHook) confPath(env Env) string {
	return filepath.Join(env.ConfigHome, "kitty", "kitty.conf")
}

// includeLines are the spellings of our include that count as connected.
func (kittyHook) includeTargets(env Env) []string {
	abs := filepath.Join(env.CacheDir, "kitty.conf")
	out := []string{abs}
	if env.Home != "" && strings.HasPrefix(abs, env.Home+string(filepath.Separator)) {
		out = append(out, "~"+strings.TrimPrefix(abs, env.Home))
	}
	return out
}

func (h kittyHook) includeLine(env Env) string {
	return "include " + h.includeTargets(env)[len(h.includeTargets(env))-1]
}

// manualInclude reports a user-written include outside our block.
func (h kittyHook) manualInclude(env Env, content string) bool {
	rest, _ := RemoveBlock(content, env.AppID)
	for _, t := range h.includeTargets(env) {
		if HasLine(rest, "include "+t) {
			return true
		}
	}
	return false
}

func (h kittyHook) present(env Env) bool {
	if _, err := os.Stat(filepath.Dir(h.confPath(env))); err == nil {
		return true
	}
	_, err := exec.LookPath("kitty")
	return err == nil
}

func (h kittyHook) Status(env Env) Status {
	st := Status{ID: h.ID(), Files: []string{h.confPath(env)}}
	data, err := os.ReadFile(h.confPath(env))
	switch {
	case err == nil:
		content := string(data)
		if _, _, ok := findBlock(content, env.AppID); ok || h.manualInclude(env, content) {
			st.State = StateConnected
		} else if isManaged(h.confPath(env)) {
			st.State, st.Reason = StateManaged, "kitty.conf is read-only or in the Nix store; add: "+h.includeLine(env)
		} else {
			st.State = StateDisconnected
		}
	case errors.Is(err, os.ErrNotExist):
		if isManaged(h.confPath(env)) {
			st.State, st.Reason = StateManaged, "kitty.conf is read-only or in the Nix store; add: "+h.includeLine(env)
		} else if !h.present(env) {
			st.State, st.Files = StateAbsent, nil
		} else {
			st.State = StateDisconnected
		}
	default:
		st.State, st.Reason = StateError, err.Error()
	}
	return st
}

func (h kittyHook) Apply(env Env) (Status, error) {
	st := h.Status(env)
	if st.State != StateDisconnected {
		return st, nil
	}
	content, existed := "", false
	if data, err := os.ReadFile(h.confPath(env)); err == nil {
		content, existed = string(data), true
	}
	out, _ := UpsertBlock(content, env.AppID, h.includeLine(env))
	if err := writeBlockFile(env, h.ID(), h.confPath(env), existed, out); err != nil {
		return failure(st, err), err
	}
	env.signal("kitty", syscall.SIGUSR1)
	return h.Status(env), nil
}

func (h kittyHook) Revert(env Env) (Status, error) {
	st := h.Status(env)
	changed, err := revertBlockFile(env, h.ID(), h.confPath(env))
	if err != nil {
		return failure(st, err), err
	}
	if changed {
		env.signal("kitty", syscall.SIGUSR1)
		return h.Status(env), nil
	}
	return st, nil
}

// failure turns a write error into a status.
func failure(st Status, err error) Status {
	if errors.Is(err, ErrManaged) {
		st.State, st.Reason = StateManaged, err.Error()
		return st
	}
	st.State, st.Reason = StateError, err.Error()
	return st
}
