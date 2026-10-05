package daemon

import (
	"net"
	"path/filepath"
	"strings"
	"testing"
	"time"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/ipc"
)

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
