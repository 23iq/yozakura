package main

import (
	"os/exec"
	"syscall"
	"testing"
	"time"
)

// `reload` used to treat the old instance as dead as soon as its IPC socket
// vanished. Shutdown closes the socket first, so the replacement started
// while the old process was still tearing down and its stray-helper sweep
// killed the new yozd daemon. waitForDeath must wait for the process.
func TestWaitForDeathWaitsForOldProcess(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir()) // no socket: isAlive() is false

	old := exec.Command("sleep", "30")
	if err := old.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = old.Process.Kill(); _ = old.Wait() }()

	const tearDown = 400 * time.Millisecond
	go func() {
		time.Sleep(tearDown)
		// Leave it unreaped: a zombie counts as dead.
		_ = syscall.Kill(old.Process.Pid, syscall.SIGKILL)
	}()

	start := time.Now()
	waitForDeath(old.Process.Pid, 5*time.Second)
	if elapsed := time.Since(start); elapsed < tearDown-50*time.Millisecond {
		t.Fatalf("waitForDeath returned after %v, before the old process exited", elapsed)
	}
	if elapsed := time.Since(start); elapsed > 3*time.Second {
		t.Fatalf("waitForDeath did not notice the zombie (took %v)", elapsed)
	}
}

func TestProcessRunning(t *testing.T) {
	if processRunning(0) || processRunning(-1) {
		t.Fatal("non-positive pid reported running")
	}
	cmd := exec.Command("sleep", "30")
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	pid := cmd.Process.Pid
	if !processRunning(pid) {
		t.Fatal("live child reported dead")
	}
	_ = cmd.Process.Kill()
	time.Sleep(200 * time.Millisecond) // zombie, not yet reaped
	if processRunning(pid) {
		t.Fatal("zombie reported running")
	}
	_ = cmd.Wait()
}
