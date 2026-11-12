package compositor

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"
)

// waitExited returns once the child exited but leaves it unreaped (a
// zombie holding its pid), so a pid read before the supervisor clears
// daemonCmd can never name a reused process; Wait still reaps it.
func TestWaitExitedLeavesTheChildUnreaped(t *testing.T) {
	cmd := exec.Command("sh", "-c", "sleep 0.1; exit 7")
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	done := make(chan struct{})
	go func() { waitExited(cmd.Process.Pid); close(done) }()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("waitExited did not return after the child exited")
	}
	stat, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", cmd.Process.Pid))
	if err != nil {
		t.Fatalf("the child was reaped by waitExited: %v", err)
	}
	if f := strings.Fields(string(stat[strings.LastIndexByte(string(stat), ')')+1:])); len(f) == 0 || f[0] != "Z" {
		t.Fatalf("child state %q, want a zombie", stat)
	}
	var ee *exec.ExitError
	if err := cmd.Wait(); !errors.As(err, &ee) || ee.ExitCode() != 7 {
		t.Fatalf("Wait: %v, want exit status 7", err)
	}
}
