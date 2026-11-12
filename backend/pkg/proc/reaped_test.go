package proc

import (
	"os/exec"
	"slices"
	"testing"
	"time"

	"yozakura/backend/pkg/proc/proctest"
)

// The detector itself: a child started and never waited for is a zombie.
func TestZombieDetectorSeesUnwaitedChild(t *testing.T) {
	cmd := exec.Command("true")
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = cmd.Wait() }()
	pid := cmd.Process.Pid
	deadline := time.Now().Add(3 * time.Second)
	for !slices.Contains(proctest.ZombieChildren(), pid) {
		if time.Now().After(deadline) {
			t.Fatalf("exited child %d not reported as a zombie", pid)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

// A fire-and-forget child is reaped once it exits.
func TestStartReapedLeavesNoZombie(t *testing.T) {
	for range 3 {
		if err := StartReaped(exec.Command("sh", "-c", "exit 0")); err != nil {
			t.Fatal(err)
		}
	}
	proctest.RequireNoZombies(t, 3*time.Second)
}

func TestStartReapedReportsStartError(t *testing.T) {
	if err := StartReaped(exec.Command("/nonexistent/binary")); err == nil {
		t.Fatal("want an error for a missing binary")
	}
}
