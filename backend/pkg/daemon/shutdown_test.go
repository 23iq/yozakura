package daemon

import (
	"net"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/svc/windows"
)

// A separate Settings / wizard window goes with the shell: shutdown (quit,
// reload, the end of the session) stops it, and none starts afterwards.
func TestShutdownStopsSeparateWindows(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, windows.EntryFile(windows.KindSettings)), []byte("ShellRoot {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	var started []windows.Process
	d := &Daemon{srv: ipc.NewServer(filepath.Join(t.TempDir(), "d.sock")), shutdownCh: make(chan struct{})}
	d.windows = windows.NewService(windows.Options{
		ShellDir: func() string { return dir },
		Start: func(argv, env []string) (windows.Process, error) {
			p, err := windows.StartGroup([]string{"sleep", "30"}, env)
			if err == nil {
				started = append(started, p)
			}
			return p, err
		},
	})
	if _, err := d.windows.Open(windows.Request{Kind: windows.KindSettings}); err != nil {
		t.Fatal(err)
	}
	d.shutdown()
	if len(started) != 1 {
		t.Fatalf("started %d windows", len(started))
	}
	if err := syscall.Kill(started[0].Pid(), 0); err == nil {
		t.Error("the settings window is still running after shutdown")
	}
	if _, err := d.windows.Open(windows.Request{Kind: windows.KindSettings}); err == nil {
		t.Error("a window started after shutdown")
	}
}

// shutdown must stop accepting IPC before it tears services down, so no
// request can start new work (agent processes, MCP servers) mid-shutdown.
func TestShutdownClosesIPCFirst(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "d.sock")
	d := &Daemon{srv: ipc.NewServer(sock), shutdownCh: make(chan struct{})}
	if err := d.srv.Listen(); err != nil {
		t.Fatal(err)
	}
	go func() { _ = d.srv.Serve() }()
	d.sweep = func() {
		if c, err := net.DialTimeout("unix", sock, time.Second); err == nil {
			_ = c.Close()
			t.Error("IPC socket still accepting connections during service teardown")
		}
	}
	d.shutdown()
}

// The post-shutdown sweep runs after the IPC socket is gone, i.e. possibly
// after a replacement instance (`reload`) already started its own children.
// It must never target processes a live instance owns and supervises
// (yozd daemon/subscribe, wl-paste, wlsunset): their services stop them.
func TestSweepSparesSupervisedChildren(t *testing.T) {
	for _, p := range strayHelperPatterns {
		for _, owned := range []string{brand.Daemon, "wl-paste", "wlsunset"} {
			if strings.Contains(p, owned) {
				t.Errorf("sweep pattern %q would kill a supervised %s of a newer instance", p, owned)
			}
		}
	}
}
