package main

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"yozakura/backend/pkg/instancelock"
)

// fakeDaemon plays the new daemon: it takes the instance lock a moment
// after being started, like the real process does after exec.
func fakeDaemon(t *testing.T, started *int32, holder *instancelock.Lock) func() {
	return func() {
		atomic.AddInt32(started, 1)
		time.Sleep(300 * time.Millisecond)
		l, err := instancelock.Acquire(instancelock.AppPath())
		if err != nil {
			t.Errorf("fake daemon refused: %v", err)
			return
		}
		*holder = *l
	}
}

func TestConcurrentReloadsStartOneDaemon(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	var started int32
	var holder instancelock.Lock
	startDaemon = fakeDaemon(t, &started, &holder)
	defer func() { startDaemon = startDetachedDaemon; holder.Release() }()

	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); restartShell() }()
	}
	wg.Wait()
	if n := atomic.LoadInt32(&started); n != 1 {
		t.Fatalf("daemons started = %d, want 1", n)
	}
}

func TestReloadWaitsForOldInstanceLock(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	old, err := instancelock.Acquire(instancelock.AppPath())
	if err != nil {
		t.Fatal(err)
	}
	released := make(chan time.Time, 1)
	go func() {
		time.Sleep(300 * time.Millisecond)
		released <- time.Now()
		old.Release()
	}()
	var startedAt time.Time
	restartShellLocked(func() { startedAt = time.Now() })
	if startedAt.Before(<-released) {
		t.Fatal("new daemon started before the old instance released its lock")
	}
}
