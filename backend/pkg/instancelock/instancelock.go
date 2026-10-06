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

// Acquire takes the exclusive lock at path without blocking and records the
// caller's pid in the file. A *HeldError is returned when it is taken.
func Acquire(path string) (*Lock, error) {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		pid := readPID(f)
		f.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil, &HeldError{Path: path, PID: pid}
		}
		return nil, err
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
// It never leaves the lock taken.
func Held(path string) (int, bool) {
	l, err := Acquire(path)
	if err == nil {
		l.Release()
		return 0, false
	}
	var he *HeldError
	if errors.As(err, &he) {
		return he.PID, true
	}
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

func runtimeFile(name string) string {
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return filepath.Join(dir, name)
	}
	return filepath.Join(os.TempDir(), fmt.Sprintf("%d-%s", os.Getuid(), name))
}

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
