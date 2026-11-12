package nightlight

import (
	"path/filepath"
	"testing"
	"time"

	"yozakura/backend/pkg/proc/proctest"
)

// wlsunset is stopped with a pkill: the exited child must be reaped, not
// left a zombie of the daemon after every night light toggle.
func TestRunFnReapsTheChild(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "pid")
	t.Setenv("PIDFILE", pidFile)
	if err := runFn("sh", "-c", `echo $$ > "$PIDFILE"`); err != nil {
		t.Fatal(err)
	}
	pid := proctest.RunPID(t, pidFile, 3*time.Second)
	proctest.RequireReaped(t, pid, 3*time.Second)
}
