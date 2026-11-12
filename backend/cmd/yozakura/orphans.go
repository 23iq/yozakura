package main

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"syscall"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/migrate"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/procscan"
	"yozakura/backend/pkg/svc/windows"
)

// notificationDaemons are stopped at every shell start so the shell can own
// the org.freedesktop.Notifications D-Bus name.
var notificationDaemons = []string{"dunst", "mako", "swaync"}

// stopNotificationDaemons SIGTERMs the user's notification daemons, matched
// by exact process name (never by a substring of a command line).
func stopNotificationDaemons(k procscan.Killer) []int {
	return k.Signal(func(p procscan.Proc) bool {
		return procscan.NamedAny(p, notificationDaemons...)
	}, syscall.SIGTERM)
}

// clipboardWatchArgv is the exact command line the clipboard service runs
// (backend/pkg/svc/clipboard/watch.go); a cliphist `wl-paste --watch` has
// another one and is left alone.
var clipboardWatchArgv = []string{"wl-paste", "--watch", "sh", "-c", "cat >/dev/null; echo REFRESH_LIST"}

// orphanTargets describes what a previous daemon of ours may have leaked.
type orphanTargets struct {
	// shellQMLs are the root QML files our Quickshell runs: shell.qml and
	// the separate windows' entry files (windows.ShellEntryFiles).
	shellQMLs []string
	// generations is the mods generations dir (<dir>/<id>/<entry file>).
	generations string
	// qsBin is a custom Quickshell binary ($<APP>_QS), "" for the default.
	qsBin string
}

func defaultOrphanTargets() orphanTargets {
	p := paths.New()
	t := orphanTargets{generations: p.ModGenerationsDir(), qsBin: brand.Env("QS")}
	dirs := []string{shellDir(), paths.FindBaseShellSource()}
	if home := os.Getenv("HOME"); home != "" {
		dirs = append(dirs, filepath.Join(home, ".local/src", brand.AppID))
	}
	for _, dir := range dirs {
		if dir == "" {
			continue
		}
		for _, name := range windows.ShellEntryFiles() {
			t.shellQMLs = append(t.shellQMLs, filepath.Join(dir, name))
		}
	}
	return t
}

// isOrphan reports whether p is a child a daemon of ours spawns: the
// keybind pipe reader, the compositor daemon and its event stream, our
// Quickshell, and our clipboard watcher.
func (t orphanTargets) isOrphan(p procscan.Proc) bool {
	return isPipeReader(p) || isOurDaemonChild(p) || t.isOurShell(p) || isClipboardWatcher(p)
}

// isPipeReader matches `tail -f <runtime>/<app>_ipc.pipe`.
func isPipeReader(p procscan.Proc) bool {
	if p.Arg0Base() != "tail" || !p.HasArg("-f") {
		return false
	}
	for i := 1; i < len(p.Argv); i++ {
		if filepath.Base(p.Argv[i]) == brand.AppID+"_ipc.pipe" {
			return true
		}
	}
	return false
}

// isOurDaemonChild matches `<daemon> [-c toml] daemon` and `<daemon> subscribe`.
func isOurDaemonChild(p procscan.Proc) bool {
	if p.Arg0Base() != brand.Daemon {
		return false
	}
	return p.HasArg("daemon") || (len(p.Argv) > 1 && p.Argv[1] == "subscribe")
}

func isClipboardWatcher(p procscan.Proc) bool {
	if len(p.Argv) != len(clipboardWatchArgv) || p.Arg0Base() != clipboardWatchArgv[0] {
		return false
	}
	for i := 1; i < len(p.Argv); i++ {
		if p.Argv[i] != clipboardWatchArgv[i] {
			return false
		}
	}
	return true
}

// isOurShell matches Quickshell running one of our shell.qml files. The pid
// in the Quickshell pid file is not trusted on its own: after a daemon crash
// it can be stale and name an unrelated process that reused the pid.
func (t orphanTargets) isOurShell(p procscan.Proc) bool {
	if !t.isQuickshell(p) {
		return false
	}
	for i := 1; i < len(p.Argv); i++ {
		a := p.Argv[i]
		var target string
		switch {
		case (a == "-p" || a == "--path") && i+1 < len(p.Argv):
			target = p.Argv[i+1]
		case strings.HasPrefix(a, "--path="):
			target = strings.TrimPrefix(a, "--path=")
		default:
			continue
		}
		if t.ourShellQML(target) {
			return true
		}
	}
	return false
}

func (t orphanTargets) isQuickshell(p procscan.Proc) bool {
	names := []string{"qs", "quickshell"}
	if t.qsBin != "" {
		names = append(names, filepath.Base(t.qsBin))
	}
	return procscan.NamedAny(p, names...)
}

func (t orphanTargets) ourShellQML(path string) bool {
	path = filepath.Clean(path)
	for _, s := range t.shellQMLs {
		if s != "" && filepath.Clean(s) == path {
			return true
		}
	}
	// any mods generation, also one a previous daemon ran before a switch
	if t.generations != "" && slices.Contains(windows.ShellEntryFiles(), filepath.Base(path)) {
		return filepath.Dir(filepath.Dir(path)) == filepath.Clean(t.generations)
	}
	return false
}

// cleanupOrphans stops the children a previous daemon of ours leaked (an
// older build that did not track them, or an unresponsive one at quit).
// Only processes that are provably ours are signalled.
func cleanupOrphans() {
	sweepOrphans(procscan.Default(), defaultOrphanTargets())
	migrate.StopLegacyDaemon()
	_ = os.Remove(ipcPipePath())
	_ = os.Remove("/tmp/" + brand.AppID + "_ipc.pipe")
}

func sweepOrphans(k procscan.Killer, t orphanTargets) []int {
	return k.Signal(t.isOrphan, syscall.SIGTERM)
}
