package instancelock

import (
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestSecondAcquireRefusedWithPID(t *testing.T) {
	p := filepath.Join(t.TempDir(), "a.lock")
	l, err := Acquire(p)
	if err != nil {
		t.Fatal(err)
	}
	_, err = Acquire(p)
	he, ok := err.(*HeldError)
	if !ok {
		t.Fatalf("want HeldError, got %v", err)
	}
	if he.PID != os.Getpid() || !strings.Contains(he.Error(), "already running (pid "+strconv.Itoa(os.Getpid())+")") {
		t.Fatalf("bad error %v", he)
	}
	l.Release()
	l2, err := Acquire(p)
	if err != nil {
		t.Fatalf("reacquire after release: %v", err)
	}
	l2.Release()
}

func TestStaleLockFileDoesNotBlock(t *testing.T) {
	p := filepath.Join(t.TempDir(), "a.lock")
	if err := os.WriteFile(p, []byte("99999\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	l, err := Acquire(p)
	if err != nil {
		t.Fatalf("stale file must not block: %v", err)
	}
	l.Release()
}

func TestConcurrentAcquireExactlyOneWins(t *testing.T) {
	p := filepath.Join(t.TempDir(), "a.lock")
	var wins int32
	var locks []*Lock
	var mu sync.Mutex
	var wg sync.WaitGroup
	for i := 0; i < 16; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if l, err := Acquire(p); err == nil {
				atomic.AddInt32(&wins, 1)
				mu.Lock()
				locks = append(locks, l)
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if wins != 1 {
		t.Fatalf("wins = %d, want 1", wins)
	}
	locks[0].Release()
}

func TestHeldAndWaitFree(t *testing.T) {
	p := filepath.Join(t.TempDir(), "a.lock")
	if _, held := Held(p); held {
		t.Fatal("free lock reported held")
	}
	l, _ := Acquire(p)
	if _, held := Held(p); !held {
		t.Fatal("held lock reported free")
	}
	if WaitFree(p, 100*time.Millisecond) {
		t.Fatal("WaitFree should time out while held")
	}
	go func() { time.Sleep(100 * time.Millisecond); l.Release() }()
	if !WaitFree(p, 3*time.Second) {
		t.Fatal("WaitFree should see the release")
	}
}

func TestRemoveIfOwned(t *testing.T) {
	dir := t.TempDir()
	sock := filepath.Join(dir, "s.sock")
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	// Go unlinks the path on Close by name; ownership checks must disable it.
	ln.(*net.UnixListener).SetUnlinkOnClose(false)
	mine := StatSocket(sock)
	// A successor replaces the socket (old inode is unlinked, new bound).
	_ = os.Remove(sock)
	ln2, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln2.Close()
	ln.Close()
	if RemoveIfOwned(sock, mine) {
		t.Fatal("removed a socket owned by another instance")
	}
	if _, err := os.Lstat(sock); err != nil {
		t.Fatalf("successor socket gone: %v", err)
	}
	if !RemoveIfOwned(sock, StatSocket(sock)) {
		t.Fatal("owner could not remove its own socket")
	}
	if RemoveIfOwned(sock, SocketID{}) {
		t.Fatal("zero id must never remove")
	}
}

func TestPaths(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", "/run/x")
	if !strings.HasPrefix(AppPath(), "/run/x/") || !strings.HasSuffix(AppPath(), ".lock") {
		t.Fatal(AppPath())
	}
	if !strings.HasSuffix(ReloadPath(), "-reload.lock") {
		t.Fatal(ReloadPath())
	}
	if filepath.Dir(DaemonPath("/a/b/s.sock")) != "/a/b" {
		t.Fatal(DaemonPath("/a/b/s.sock"))
	}
}
