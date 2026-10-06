package apphooks

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// fileHook connects a terminal whose config can include another file via one
// marked block. Variants differ in file location, the block body, where the
// block goes, what counts as a hand-written include and when the file is too
// structured to edit safely.
type fileHook struct {
	id    string
	bin   string
	procs []string
	atTop bool
	// file is the config path; body the block content for env.
	file func(Env) string
	body func(Env) string
	// manual reports an equivalent user-written include outside our block.
	manual func(Env, string) bool
	// guard returns a non-empty hint when the content cannot be edited
	// safely (we then report error/manual and never write).
	guard func(Env, string) string
}

func (h fileHook) ID() string { return h.id }

func (h fileHook) present(env Env) bool {
	if _, err := os.Stat(filepath.Dir(h.file(env))); err == nil {
		return true
	}
	_, err := lookPath(h.bin)
	return err == nil
}

func (h fileHook) Status(env Env) Status {
	path := h.file(env)
	st := Status{ID: h.id, Files: []string{path}}
	data, err := os.ReadFile(path)
	switch {
	case err == nil:
		content := string(data)
		rest, _ := RemoveBlock(content, env.AppID)
		if _, _, ok := findBlock(content, env.AppID); ok || h.manual(env, rest) {
			st.State = StateConnected
			st.NeedsRestart = env.running(h.procs...)
		} else if hint := h.guard(env, content); hint != "" {
			st.State, st.Reason = StateError, "manual: "+hint
		} else if isManaged(path) {
			st.State, st.Reason = StateManaged, filepath.Base(path)+" is read-only or in the Nix store; add: "+h.body(env)
		} else {
			st.State = StateDisconnected
		}
	case errors.Is(err, os.ErrNotExist):
		if !h.present(env) {
			st.State, st.Files = StateAbsent, nil
		} else if isManaged(path) {
			st.State, st.Reason = StateManaged, filepath.Base(path)+" is read-only or in the Nix store; add: "+h.body(env)
		} else {
			st.State = StateDisconnected
		}
	default:
		st.State, st.Reason = StateError, err.Error()
	}
	return st
}

func (h fileHook) Apply(env Env) (Status, error) {
	st := h.Status(env)
	if st.State != StateDisconnected {
		return st, nil
	}
	content := ""
	if data, err := os.ReadFile(h.file(env)); err == nil {
		content = string(data)
	}
	out, _ := UpsertBlockAt(content, env.AppID, h.body(env), h.atTop)
	if err := WriteFileSafe(h.file(env), []byte(out)); err != nil {
		return failure(st, err), err
	}
	return h.Status(env), nil
}

func (h fileHook) Revert(env Env) (Status, error) {
	st := h.Status(env)
	path := h.file(env)
	data, err := os.ReadFile(path)
	if err != nil {
		return st, nil
	}
	out, changed := RemoveBlock(string(data), env.AppID)
	if !changed {
		return st, nil
	}
	if isManaged(path) {
		return failure(st, ErrManaged), ErrManaged
	}
	if strings.TrimSpace(out) == "" {
		err = os.Remove(path) // we created it: leave nothing behind
	} else {
		err = WriteFileSafe(path, []byte(out))
	}
	if err != nil {
		return failure(st, err), err
	}
	return h.Status(env), nil
}

// cacheTargets are the spellings of a file in the cache dir: absolute, and
// ~-relative when it lives under $HOME. The ~ form is listed last and used
// in generated lines.
func cacheTargets(env Env, name string) []string {
	abs := filepath.Join(env.CacheDir, name)
	out := []string{abs}
	if env.Home != "" && strings.HasPrefix(abs, env.Home+string(filepath.Separator)) {
		out = append(out, "~"+strings.TrimPrefix(abs, env.Home))
	}
	return out
}

func cachePath(env Env, name string) string {
	t := cacheTargets(env, name)
	return t[len(t)-1]
}

// hasKeyValue reports an uncommented `key = value` line (spaces around '='
// and an optional leading '?' or quotes on the value ignored) whose value is
// one of values.
func hasKeyValue(content, key string, values []string) bool {
	for _, l := range strings.Split(content, "\n") {
		k, v, ok := strings.Cut(strings.TrimSpace(l), "=")
		if !ok || strings.TrimSpace(k) != key {
			continue
		}
		v = strings.Trim(strings.TrimLeft(strings.TrimSpace(v), "?"), `"'`)
		for _, want := range values {
			if v == want {
				return true
			}
		}
	}
	return false
}

func noGuard(Env, string) string { return "" }

func init() {
	Register(fileHook{
		id: "ghostty", bin: "ghostty", procs: []string{"ghostty"},
		file: func(env Env) string {
			dir := filepath.Join(env.ConfigHome, "ghostty")
			if _, err := os.Stat(filepath.Join(dir, "config.ghostty")); err == nil {
				return filepath.Join(dir, "config.ghostty")
			}
			return filepath.Join(dir, "config")
		},
		body: func(env Env) string { return "config-file = " + cachePath(env, "ghostty.conf") },
		manual: func(env Env, c string) bool {
			return hasKeyValue(c, "config-file", cacheTargets(env, "ghostty.conf"))
		},
		guard: noGuard,
	})
	Register(fileHook{
		id: "foot", bin: "foot", procs: []string{"foot", "footclient"}, atTop: true,
		file: func(env Env) string { return filepath.Join(env.ConfigHome, "foot", "foot.ini") },
		body: func(env Env) string { return "include=" + cachePath(env, "foot.ini") },
		manual: func(env Env, c string) bool {
			return hasKeyValue(c, "include", cacheTargets(env, "foot.ini"))
		},
		guard: noGuard,
	})
	Register(alacrittyHook())
}

// alacrittyHook edits TOML only by adding a marked [general] block at the
// end; a file that already has [general] (or a dotted/inline general key) is
// never rewritten: the user is told the exact line to add.
func alacrittyHook() fileHook {
	return fileHook{
		id: "alacritty", bin: "alacritty", procs: []string{"alacritty"},
		file: func(env Env) string { return filepath.Join(env.ConfigHome, "alacritty", "alacritty.toml") },
		body: func(env Env) string {
			return "[general]\nimport = [\"" + cachePath(env, "alacritty.toml") + "\"]"
		},
		manual: func(env Env, c string) bool {
			for _, l := range strings.Split(c, "\n") {
				t := strings.TrimSpace(l)
				if strings.HasPrefix(t, "#") {
					continue
				}
				for _, target := range cacheTargets(env, "alacritty.toml") {
					if strings.Contains(t, `"`+target+`"`) || strings.Contains(t, `'`+target+`'`) {
						return true
					}
				}
			}
			return false
		},
		guard: func(env Env, c string) string {
			for _, l := range strings.Split(c, "\n") {
				t := strings.TrimSpace(l)
				if strings.HasPrefix(t, "[general") || strings.HasPrefix(t, "general.") || strings.HasPrefix(t, "general ") || strings.HasPrefix(t, "general=") || strings.HasPrefix(t, "import ") || strings.HasPrefix(t, "import=") {
					return "add \"" + cachePath(env, "alacritty.toml") + "\" to import = [...] under [general] in alacritty.toml"
				}
			}
			return ""
		},
	}
}
