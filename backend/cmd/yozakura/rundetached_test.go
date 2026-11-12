package main

import (
	"path/filepath"
	"testing"
	"time"

	"yozakura/backend/pkg/proc/proctest"
)

// The daemon's fire-and-forget start-up commands (easyeffects restart) are
// reaped once they exit instead of staying zombies of the daemon.
func TestRunDetachedReapsTheCommand(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "pid")
	t.Setenv("PIDFILE", pidFile)
	runDetached(`echo $$ > "$PIDFILE"`)
	pid := proctest.RunPID(t, pidFile, 3*time.Second)
	proctest.RequireReaped(t, pid, 3*time.Second)
}
