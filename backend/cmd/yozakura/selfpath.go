package main

import (
	"os"
	"path/filepath"
	"strings"
)

// ensureSelfOnPath appends the directory of the running binary to PATH so
// everything the shell spawns (quickshell, the daemon, `sh -c "yozakura
// lock"` from idle/lock settings) can call the CLI by name. Display
// managers often start the session with a PATH that lacks ~/.local/bin
// even when the user's interactive shell (e.g. fish) adds it.
func ensureSelfOnPath() {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	if next, changed := pathWithDir(os.Getenv("PATH"), filepath.Dir(exe)); changed {
		os.Setenv("PATH", next)
	}
}

// pathWithDir returns path with dir appended, unless it is already listed.
func pathWithDir(path, dir string) (string, bool) {
	if dir == "" {
		return path, false
	}
	clean := filepath.Clean(dir)
	for _, p := range filepath.SplitList(path) {
		if p != "" && filepath.Clean(p) == clean {
			return path, false
		}
	}
	if path == "" {
		return dir, true
	}
	return strings.TrimRight(path, string(os.PathListSeparator)) + string(os.PathListSeparator) + dir, true
}
