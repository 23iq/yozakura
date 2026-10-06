package main

import (
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"yozakura/backend/pkg/instancelock"
)

// fakeDaemon plays the new daemon: it takes the instance lock a moment
// after being started, like the real process does after exec.
func fakeDaemon(t *testing.T, started *int32, holder *instancelock.Lock) func() {
	return func() {
		atomic.AddInt32(started, 1)
		time.Sleep(150 * time.Millisecond) // window in which the other reloads arrive
		l, err := instancelock.Acquire(instancelock.AppPath())
		if err != nil {
			t.Errorf("fake daemon refused: %v", err)
			return
		}
		*holder = *l
	}
}

func fastTimeouts(t *testing.T) {
	o1, o2, o3 := stopWait, killWait, startWait
	stopWait, killWait, startWait = 300*time.Millisecond, 200*time.Millisecond, 300*time.Millisecond
	t.Cleanup(func() { stopWait, killWait, startWait = o1, o2, o3 })
}

func TestConcurrentReloadsStartOneDaemon(t *testing.T) {
	fastTimeouts(t)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	var started int32
	var holder instancelock.Lock
	startDaemon = fakeDaemon(t, &started, &holder)
	oldOurs, oldSig := isOurProcess, signalPID
	isOurProcess = func(int) bool { return false } // never signal the test process
	signalPID = func(int, syscall.Signal) error { t.Error("unexpected signal"); return nil }
	defer func() { startDaemon = startDetachedDaemon; isOurProcess, signalPID = oldOurs, oldSig; holder.Release() }()

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
	fastTimeouts(t)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	old, err := instancelock.Acquire(instancelock.AppPath())
	if err != nil {
		t.Fatal(err)
	}
	released := make(chan time.Time, 1)
	go func() {
		released <- time.Now()
		old.Release()
	}()
	var startedAt time.Time
	restartShellLocked(func() {
		startedAt = time.Now()
		l, _ := instancelock.Acquire(instancelock.AppPath())
		t.Cleanup(l.Release)
	})
	if startedAt.Before(<-released) {
		t.Fatal("new daemon started before the old instance released its lock")
	}
}

func TestReloadRefusesToKillForeignHolder(t *testing.T) {
	fastTimeouts(t)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	hold, err := instancelock.Acquire(instancelock.AppPath())
	if err != nil {
		t.Fatal(err)
	}
	defer hold.Release()
	oldOurs, oldSig := isOurProcess, signalPID
	defer func() { isOurProcess, signalPID = oldOurs, oldSig }()
	isOurProcess = func(int) bool { return false }
	signalPID = func(int, syscall.Signal) error { t.Error("signalled a foreign process"); return nil }
	started := false
	if restartShellLocked(func() { started = true }) || started {
		t.Fatal("must not start while an unkillable holder remains")
	}
}

func TestReloadForceStopsStuckHolder(t *testing.T) {
	fastTimeouts(t)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	hold, err := instancelock.Acquire(instancelock.AppPath())
	if err != nil {
		t.Fatal(err)
	}
	defer hold.Release()
	oldOurs, oldSig := isOurProcess, signalPID
	defer func() { isOurProcess, signalPID = oldOurs, oldSig }()
	isOurProcess = func(int) bool { return true }
	var sigs []syscall.Signal
	signalPID = func(_ int, s syscall.Signal) error {
		sigs = append(sigs, s)
		if s == syscall.SIGKILL {
			hold.Release() // the kill "works"
		}
		return nil
	}
	started := false
	if !restartShellLocked(func() { started = true }) || !started {
		t.Fatal("expected restart after force stop")
	}
	if len(sigs) != 2 || sigs[0] != syscall.SIGTERM || sigs[1] != syscall.SIGKILL {
		t.Fatalf("signals = %v", sigs)
	}
}
