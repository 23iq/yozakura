package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"yozakura/backend/pkg/brand"
)

// detectLegacyDaemon reports whether a session of the legacy app (the
// project this one was renamed from) is alive: its supervised Quickshell
// or daemon pid file in runtimeDir names a live process. A leftover socket
// alone does not count, and stale pid files are ignored.
func detectLegacyDaemon(runtimeDir string) (pid int, running bool) {
	for _, name := range []string{brand.LegacyAppID + "-qs.pid", brand.LegacyAppID + ".pid"} {
		data, err := os.ReadFile(filepath.Join(runtimeDir, name))
		if err != nil {
			continue
		}
		p, err := strconv.Atoi(strings.TrimSpace(string(data)))
		if err != nil || p <= 0 {
			continue
		}
		if err := syscall.Kill(p, 0); err == nil || err == syscall.EPERM {
			return p, true
		}
	}
	return 0, false
}

// refuseIfLegacyRunning stops the launch while a legacy session is alive:
// two shells would mean two bars, two notification daemons and fighting
// keybinds.
func refuseIfLegacyRunning() {
	if brand.LegacyAppID == brand.AppID {
		return
	}
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = "/tmp"
	}
	if pid, running := detectLegacyDaemon(runtimeDir); running {
		fmt.Fprintf(os.Stderr, "An %s session is still running (pid %d). Run '%s quit' first.\n",
			brand.LegacyName, pid, brand.LegacyAppID)
		os.Exit(1)
	}
}
