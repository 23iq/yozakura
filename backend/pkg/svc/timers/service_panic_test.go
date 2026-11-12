package timers

import (
	"testing"
	"time"
)

// A request that panics under the lock (the IPC server recovers it) must
// not leave the lock held: the next request still runs.
func TestMutatePanicReleasesLock(t *testing.T) {
	s := NewService(Options{})
	func() {
		defer func() { _ = recover() }()
		_, _ = s.mutate(func(*Engine) (any, error) { panic("boom") })
	}()
	done := make(chan struct{})
	go func() {
		_ = s.View()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("the timers lock is still held after a panicking request")
	}
}
