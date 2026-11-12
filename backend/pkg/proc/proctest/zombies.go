// Package proctest holds test helpers about the processes a test starts.
package proctest

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// ZombieChildren returns the pids of this process's children that exited
// and were never waited for (state Z in /proc).
func ZombieChildren() []int {
	self := os.Getpid()
	dirs, _ := filepath.Glob("/proc/[0-9]*")
	var out []int
	for _, dir := range dirs {
		data, err := os.ReadFile(filepath.Join(dir, "stat"))
		if err != nil {
			continue
		}
		// "pid (comm) S ppid ...": comm may hold spaces and parentheses
		s := string(data)
		i := strings.LastIndexByte(s, ')')
		if i < 0 {
			continue
		}
		f := strings.Fields(s[i+1:])
		if len(f) < 2 || f[0] != "Z" {
			continue
		}
		if ppid, err := strconv.Atoi(f[1]); err != nil || ppid != self {
			continue
		}
		if pid, err := strconv.Atoi(filepath.Base(dir)); err == nil {
			out = append(out, pid)
		}
	}
	return out
}

// RequireReaped fails the test unless pid is gone within timeout, zombie
// included: a process stays in /proc until its parent waits for it.
func RequireReaped(t testing.TB, pid int, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for {
		if _, err := os.Stat("/proc/" + strconv.Itoa(pid)); err != nil {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("child %d never reaped (still in /proc)", pid)
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// RunPID waits up to timeout for a child to write its pid ($$) to path.
func RunPID(t testing.TB, path string, timeout time.Duration) int {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for {
		if data, err := os.ReadFile(path); err == nil {
			if pid, err := strconv.Atoi(strings.TrimSpace(string(data))); err == nil && pid > 0 {
				return pid
			}
		}
		if time.Now().After(deadline) {
			t.Fatalf("no pid written to %s", path)
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// RequireNoZombies fails the test when a child of this process is still a
// zombie after timeout (a child that just exited gets that long to be
// reaped by whoever waits for it).
func RequireNoZombies(t testing.TB, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for {
		z := ZombieChildren()
		if len(z) == 0 {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("zombie children never reaped: %v", z)
		}
		time.Sleep(20 * time.Millisecond)
	}
}
