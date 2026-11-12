package sleep

import (
	"path/filepath"
	"testing"
	"time"

	"yozakura/backend/pkg/proc/proctest"
)

// A configured sleep/lock command is reaped once it exits; it used to stay
// a zombie of the daemon for the rest of the session.
func TestRunDetachedReapsTheCommand(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "pid")
	t.Setenv("PIDFILE", pidFile)
	runDetached(`echo $$ > "$PIDFILE"`)
	pid := proctest.RunPID(t, pidFile, 3*time.Second)
	proctest.RequireReaped(t, pid, 3*time.Second)
}
