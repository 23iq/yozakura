package voice

import (
	"testing"
	"time"
)

// wl-copy forks a daemon that keeps the inherited stdout/stderr open. The
// runner must not wait for those pipes to close, or voice.type never
// returns (and blocks the IPC connection it runs on).
func TestExecRunnerDoesNotWaitForBackgroundChildren(t *testing.T) {
	done := make(chan error, 1)
	go func() { done <- execRunner("", "sh", "-c", "sleep 5 & exit 0") }()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("execRunner: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("execRunner blocked on a background child holding the output pipes")
	}
}

func TestExecRunnerReportsFailure(t *testing.T) {
	if err := execRunner("", "sh", "-c", "exit 3"); err == nil {
		t.Fatal("expected an error for a non-zero exit")
	}
}

// Typing spawns child processes (and can wait on a compositor); it must run
// off the connection's serial request loop.
func TestTypeIsAsync(t *testing.T) {
	svc := &Service{}
	if !svc.ipcService().Async["type"] {
		t.Fatal("voice.type must be listed in the Async map")
	}
}
