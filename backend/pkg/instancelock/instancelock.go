// Package instancelock gives long-lived daemons a single-instance guarantee
// based on flock(2), plus helpers to remove a Unix socket only when this
// process still owns it. The kernel drops the lock when the holder dies, so
// a stale lock file never blocks a restart (unlike a socket dial check).
package instancelock

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
)

// HeldError reports that another process holds the lock.
type HeldError struct {
	Path string
	PID  int // 0 when unknown
}

func (e *HeldError) Error() string {
	if e.PID > 0 {
		return fmt.Sprintf("already running (pid %d)", e.PID)
	}
	return "already running"
}

// Lock is an exclusive flock held until Release or process exit. The file
// is opened close-on-exec, so spawned children never inherit the lock.
type Lock struct {
	f *os.File
}

// acquireRetry is how long Acquire keeps retrying a lock that looks taken:
// probes (Held) briefly take a shared lock, which must never make a real
// daemon believe another instance is running.
const acquireRetry = 500 * time.Millisecond

// ExitHeld is the exit status of a daemon that refused to start because
// another instance holds its lock; supervisors treat it as "do not respawn".
const ExitHeld = 3

// Acquire takes the exclusive lock at path and records the caller's pid in
// the file. A lock that stays taken for ~500 ms yields a *HeldError.
func Acquire(path string) (*Lock, error) { return acquire(path, acquireRetry) }

// TryAcquire is Acquire without the retry window, for locks where losing
// immediately is the point (collapsing concurrent reloads).
func TryAcquire(path string) (*Lock, error) { return acquire(path, 0) }

func acquire(path string, retry time.Duration) (*Lock, error) {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return nil, err
	}
	deadline := time.Now().Add(retry)
	for {
		err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			break
		}
		if !errors.Is(err, syscall.EWOULDBLOCK) {
			f.Close()
			return nil, err
		}
		if !time.Now().Before(deadline) {
			pid := readPID(f)
			f.Close()
			return nil, &HeldError{Path: path, PID: pid}
		}
		time.Sleep(5 * time.Millisecond)
	}
	_ = f.Truncate(0)
	_, _ = f.WriteAt([]byte(strconv.Itoa(os.Getpid())+"\n"), 0)
	return &Lock{f: f}, nil
}

// Release drops the lock. Safe on a nil Lock and to call twice.
func (l *Lock) Release() {
	if l == nil || l.f == nil {
		return
	}
	_ = syscall.Flock(int(l.f.Fd()), syscall.LOCK_UN)
	l.f.Close()
	l.f = nil
}

// Held reports whether another holder owns the lock at path (and its pid).
// It is a read-only probe: no file is created and nothing is written; a
// missing file means not held.
func Held(path string) (int, bool) {
	f, err := os.Open(path)
	if err != nil {
		return 0, false
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_SH|syscall.LOCK_NB); err != nil {
		return readPID(f), errors.Is(err, syscall.EWOULDBLOCK)
	}
	_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	return 0, false
}

// WaitFree polls until the lock at path is not held or timeout elapses.
// It reports whether the lock became free.
func WaitFree(path string, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for {
		if _, held := Held(path); !held {
			return true
		}
		if !time.Now().Before(deadline) {
			return false
		}
		time.Sleep(25 * time.Millisecond)
	}
}

func readPID(f *os.File) int {
	buf := make([]byte, 32)
	n, _ := f.ReadAt(buf, 0)
	pid, _ := strconv.Atoi(strings.TrimSpace(string(buf[:n])))
	return pid
}

func runtimeFile(name string) string { return filepath.Join(paths.RuntimeDir(), name) }

// AppPath is the lock held for the whole life of the app daemon.
func AppPath() string { return runtimeFile(brand.AppID + ".lock") }

// ReloadPath is the short-lived lock that serialises `reload`.
func ReloadPath() string { return runtimeFile(brand.AppID + "-reload.lock") }

// DaemonPath is the compositor daemon's lock, next to its socket so a
// socket override gets its own instance.
func DaemonPath(socketPath string) string {
	return filepath.Join(filepath.Dir(socketPath), brand.Daemon+".lock")
}

// SocketID identifies a socket file by device and inode.
type SocketID struct {
	dev, ino uint64
	ok       bool
}

// StatSocket records the identity of the socket currently at path; call it
// right after binding.
func StatSocket(path string) SocketID {
	var st syscall.Stat_t
	if err := syscall.Lstat(path, &st); err != nil {
		return SocketID{}
	}
	return SocketID{dev: uint64(st.Dev), ino: st.Ino, ok: true} //nolint:unconvert
}

// RemoveIfOwned unlinks path only when it is still the socket recorded in
// id, so a stopping instance never deletes a successor's socket. It reports
// whether the file was removed.
func RemoveIfOwned(path string, id SocketID) bool {
	if !id.ok || StatSocket(path) != id {
		return false
	}
	return os.Remove(path) == nil
}
