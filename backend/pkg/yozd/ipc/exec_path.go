package ipc

import (
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
)

// execBinDir returns the directory holding the daemon binary; the CLI is
// installed next to it. Overridable in tests.
var execBinDir = func() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	return filepath.Dir(exe)
}

// ResolveExecCommand rewrites a bind command that starts with the CLI or
// daemon name ("yozakura run launcher") to call that binary by absolute
// path. Compositors exec binds with the session PATH, which often lacks
// ~/.local/bin (e.g. a fish-only PATH under SDDM), so a bare name would
// fail silently. Commands for other programs, or when the binary is not
// found next to the daemon, are returned unchanged.
func ResolveExecCommand(cmd string) string {
	trimmed := strings.TrimLeft(cmd, " \t")
	name, rest, _ := strings.Cut(trimmed, " ")
	if name != brand.AppID && name != brand.Daemon {
		return cmd
	}
	dir := execBinDir()
	if dir == "" {
		return cmd
	}
	path := filepath.Join(dir, name)
	if info, err := os.Stat(path); err != nil || info.IsDir() || info.Mode()&0o111 == 0 {
		return cmd
	}
	if strings.ContainsAny(path, " \t'\"$`\\") {
		path = "'" + strings.ReplaceAll(path, "'", `'\''`) + "'"
	}
	if rest == "" {
		return path
	}
	return path + " " + rest
}

// IsExecDispatcher reports whether a bind runs a shell command.
func IsExecDispatcher(dispatcher string) bool {
	return dispatcher == "" || dispatcher == "exec" || dispatcher == "spawn"
}

// ResolveBindArgument applies ResolveExecCommand to exec-style binds and
// leaves every other dispatcher's argument untouched.
func ResolveBindArgument(kb Keybind) string {
	if !IsExecDispatcher(kb.Dispatcher) {
		return kb.Argument
	}
	return ResolveExecCommand(kb.Argument)
}
