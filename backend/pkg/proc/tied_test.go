package proc

import (
	"os/exec"
	"runtime"
	"syscall"
	"testing"
	"time"
)

// startOnDyingThread starts a child from a goroutine that locks its OS thread
// and returns without unlocking, which makes the Go runtime terminate that
// thread right after the spawn.
func startOnDyingThread(t *testing.T, start func(*exec.Cmd) error) *exec.Cmd {
	t.Helper()
	cmd := exec.Command("sleep", "30")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	errc := make(chan error, 1)
	go func() {
		runtime.LockOSThread() // never unlocked: the thread exits with us
		errc <- start(cmd)
	}()
	if err := <-errc; err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = cmd.Process.Kill(); _ = cmd.Wait() })
	return cmd
}

// exitedWithin reports whether cmd exits within d, and how.
func exitedWithin(cmd *exec.Cmd, d time.Duration) (bool, error) {
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		return true, err
	case <-time.After(d):
		return false, nil
	}
}

func TestStartTiedSurvivesSpawningThreadExit(t *testing.T) {
	cmd := startOnDyingThread(t, StartTied)
	if a := cmd.SysProcAttr; !a.Setpgid || a.Pdeathsig != syscall.SIGTERM {
		t.Fatalf("SysProcAttr = %+v, want Setpgid kept and Pdeathsig=SIGTERM", a)
	}
	if exited, err := exitedWithin(cmd, 500*time.Millisecond); exited {
		t.Fatalf("child died when the spawning goroutine's thread exited: %v", err)
	}
}

// The failure StartTied prevents: Pdeathsig on a plain Start follows the
// forking thread, not the process.
func TestPlainPdeathsigFollowsTheThread(t *testing.T) {
	cmd := startOnDyingThread(t, func(c *exec.Cmd) error {
		c.SysProcAttr.Pdeathsig = syscall.SIGTERM
		return c.Start()
	})
	exited, err := exitedWithin(cmd, 2*time.Second)
	if !exited {
		t.Skip("kernel/runtime did not reap the locked thread; nothing to demonstrate")
	}
	if ee, ok := err.(*exec.ExitError); !ok || ee.Sys().(syscall.WaitStatus).Signal() != syscall.SIGTERM {
		t.Fatalf("child exit = %v, want SIGTERM from Pdeathsig", err)
	}
}
