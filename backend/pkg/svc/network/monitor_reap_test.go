package network

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/proc/proctest"
)

// An ended subscription kills its `nmcli monitor` and reaps it: it used to
// stay a zombie of the daemon, one per shell restart.
func TestSubscribeReapsMonitorWhenItEnds(t *testing.T) {
	stubDir := t.TempDir()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(exe, filepath.Join(stubDir, "nmcli")); err != nil {
		t.Fatal(err)
	}
	pidFile := filepath.Join(t.TempDir(), "monitor.pid")
	t.Setenv("PATH", stubDir+":"+os.Getenv("PATH"))
	t.Setenv("AUDIT_STUB", "1")
	t.Setenv("AUDIT_NMCLI_LOG", "")
	t.Setenv("AUDIT_MONITOR_PID", pidFile)

	sub := ipc.NewSubscriber(16)
	done := make(chan struct{})
	go func() {
		defer close(done)
		NewService().subscribe(sub)
	}()
	pid := proctest.RunPID(t, pidFile, 20*time.Second)
	sub.Stop()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("subscribe did not return after Stop")
	}
	proctest.RequireReaped(t, pid, 3*time.Second)
}
