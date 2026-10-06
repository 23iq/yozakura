package apphooks

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// lookPath is exec.LookPath; tests replace it.
var lookPath = exec.LookPath

type qtHook struct{}

func init() { Register(qtHook{}) }

func (qtHook) ID() string { return "qt" }

func (qtHook) envFile(env Env) string {
	return filepath.Join(env.ConfigHome, "environment.d", "90-"+env.AppID+"-qt.conf")
}

// platformTheme is the qtct flavour to select, "" when neither is installed.
func (qtHook) platformTheme() string {
	for _, b := range []string{"qt6ct", "qt5ct"} {
		if _, err := lookPath(b); err == nil {
			return b
		}
	}
	return ""
}

func (h qtHook) content(env Env) string {
	return "# Written by " + env.AppID + " (Settings > Terminal & Apps). Removed when theming is switched off.\n" +
		"QT_QPA_PLATFORMTHEME=" + h.platformTheme() + "\n"
}

// owned reports whether data is a file this hook wrote.
func (qtHook) owned(env Env, data []byte) bool {
	return strings.HasPrefix(string(data), "# Written by "+env.AppID+" ")
}

func (h qtHook) Status(env Env) Status {
	st := Status{ID: h.ID(), Files: []string{h.envFile(env)}}
	data, err := os.ReadFile(h.envFile(env))
	switch {
	case err == nil && !h.owned(env, data):
		st.State, st.Reason = StateManaged, "environment.d already has a file of that name; set QT_QPA_PLATFORMTHEME="+h.platformTheme()
	case err == nil:
		st.State = StateConnected
		if os.Getenv("QT_QPA_PLATFORMTHEME") == "" {
			st.Reason = "relogin" // environment.d is read at session start
		}
	case errors.Is(err, os.ErrNotExist):
		switch {
		case h.platformTheme() == "":
			st.State, st.Files = StateAbsent, nil
		case isManaged(h.envFile(env)):
			st.State, st.Reason = StateManaged, "environment.d is read-only or in the Nix store; set QT_QPA_PLATFORMTHEME="+h.platformTheme()
		default:
			st.State = StateDisconnected
		}
	default:
		st.State, st.Reason = StateError, err.Error()
	}
	return st
}

func (h qtHook) Apply(env Env) (Status, error) {
	st := h.Status(env)
	if st.State != StateDisconnected {
		return st, nil
	}
	if err := WriteFileSafe(h.envFile(env), []byte(h.content(env))); err != nil {
		return failure(st, err), err
	}
	return h.Status(env), nil
}

func (h qtHook) Revert(env Env) (Status, error) {
	st := h.Status(env)
	data, err := os.ReadFile(h.envFile(env))
	if err != nil || !h.owned(env, data) {
		return st, nil // not ours: leave it
	}
	if isManaged(h.envFile(env)) {
		return failure(st, ErrManaged), ErrManaged
	}
	if err := removeFile(h.envFile(env)); err != nil {
		return failure(st, err), err
	}
	st = h.Status(env)
	st.Reason = ""
	return st, nil
}
