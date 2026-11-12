package main

import (
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/procscan"
)

func writeFakeProc(t *testing.T, root string, pid int, comm string, argv ...string) {
	t.Helper()
	dir := filepath.Join(root, strconv.Itoa(pid))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "comm"), []byte(comm+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "cmdline"), []byte(strings.Join(argv, "\x00")+"\x00"), 0o644); err != nil {
		t.Fatal(err)
	}
}

func recordingKiller(root string, self int, got *[]int) procscan.Killer {
	return procscan.Killer{Root: root, UID: os.Getuid(), Self: self, Kill: func(pid int, _ syscall.Signal) error {
		*got = append(*got, pid)
		return nil
	}}
}

func TestStopNotificationDaemonsMatchesExactNames(t *testing.T) {
	root := t.TempDir()
	writeFakeProc(t, root, 100, "dunst", "/usr/bin/dunst")
	writeFakeProc(t, root, 101, "mako", "mako")
	writeFakeProc(t, root, 102, "swaync", "swaync")
	writeFakeProc(t, root, 103, "nvim", "nvim", "mako_template.py")
	// a home dir containing "mako": the old regex made the daemon kill itself
	writeFakeProc(t, root, 104, brand.AppID, "/home/tamako/.local/bin/"+brand.AppID)
	writeFakeProc(t, root, 105, "makoctl", "makoctl", "dismiss")
	writeFakeProc(t, root, 106, "less", "less", "/var/log/swaync.log")
	var got []int
	stopNotificationDaemons(recordingKiller(root, 1, &got))
	slices.Sort(got)
	if !slices.Equal(got, []int{100, 101, 102}) {
		t.Fatalf("signalled %v, want [100 101 102]", got)
	}
}

// The clipboard watcher argv here must stay the one the clipboard service
// spawns, or a leaked watcher of ours is no longer recognised.
func TestClipboardWatchArgvMatchesService(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "..", "pkg", "svc", "clipboard", "watch.go"))
	if err != nil {
		t.Fatal(err)
	}
	quoted := make([]string, len(clipboardWatchArgv))
	for i, a := range clipboardWatchArgv {
		quoted[i] = strconv.Quote(a)
	}
	if call := strings.Join(quoted, ", "); !strings.Contains(string(src), call) {
		t.Fatalf("watch.go no longer spawns %s", call)
	}
}

func TestSweepOrphansOnlyOurs(t *testing.T) {
	root := t.TempDir()
	shell := "/opt/yz/shell.qml"
	gens := "/home/u/.local/share/yz/mods/generations"
	ours := []int{200, 201, 202, 203, 204, 205}
	writeFakeProc(t, root, 200, "tail", "tail", "-f", "/run/user/1000/"+brand.AppID+"_ipc.pipe")
	writeFakeProc(t, root, 201, brand.Daemon, "/usr/bin/"+brand.Daemon, "-c", "/x/"+brand.Daemon+".toml", "daemon")
	writeFakeProc(t, root, 202, brand.Daemon, brand.Daemon, "subscribe")
	writeFakeProc(t, root, 203, "qs", "qs", "-p", shell)
	writeFakeProc(t, root, 204, ".quickshell-wra", "/nix/store/q/bin/qs", "-p", gens+"/g42/shell.qml")
	writeFakeProc(t, root, 205, "wl-paste", clipboardWatchArgv...)

	writeFakeProc(t, root, 300, "wl-paste", "wl-paste", "--watch", "cliphist", "store")
	writeFakeProc(t, root, 301, "qs", "qs", "-p", "/home/u/.config/quickshell/other/shell.qml")
	writeFakeProc(t, root, 302, "nvim", "nvim", "-p", shell)
	writeFakeProc(t, root, 303, "nvim", "nvim", "backend/cmd/"+brand.Daemon+"/daemon.go")
	writeFakeProc(t, root, 304, brand.Daemon, brand.Daemon, "monitor", "list")
	writeFakeProc(t, root, 305, "tail", "tail", "-f", "/var/log/syslog")
	// a stale Quickshell pid file names a pid an editor now has: not ours
	writeFakeProc(t, root, 306, "nvim", "nvim", "/home/u/.config/quickshell/other/shell.qml")
	writeFakeProc(t, root, 307, "custom-qs", "custom-qs", "-p", "/elsewhere/shell.qml")

	tg := orphanTargets{shellQMLs: []string{shell}, generations: gens}
	var got []int
	sweepOrphans(recordingKiller(root, 1, &got), tg)
	slices.Sort(got)
	if !slices.Equal(got, ours) {
		t.Fatalf("signalled %v, want %v", got, ours)
	}
}

// A stale Quickshell pid file (the daemon crashed) can name a pid another
// process reused, here an editor on some shell.qml: it is not signalled.
func TestSweepOrphansIgnoresStaleQsPidFile(t *testing.T) {
	runtime := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtime)
	root := t.TempDir()
	writeFakeProc(t, root, 400, "nvim", "nvim", "/home/u/.config/quickshell/other/shell.qml")
	writeFakeProc(t, root, 401, "custom-qs", "custom-qs", "-p", "/elsewhere/shell.qml")
	for _, pid := range []string{"400", "401"} {
		if err := os.WriteFile(filepath.Join(runtime, brand.AppID+"-qs.pid"), []byte(pid+"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		var got []int
		sweepOrphans(recordingKiller(root, 1, &got), defaultOrphanTargets())
		if len(got) != 0 {
			t.Fatalf("pid file %s: signalled %v, want none", pid, got)
		}
	}
}
