package mcp

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// An npx-style server: the direct child ignores stdin EOF and a grandchild
// keeps stdout/stderr open. Close must still return and leave nothing behind.
func TestStdioCloseKillsProcessGroup(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "grandchild.pid")
	script := `sleep 300 & echo $! > "$1"; cat >/dev/null; sleep 300`
	c, err := StartStdio("sh", []string{"-c", script, "sh", pidFile}, nil, "")
	if err != nil {
		t.Fatal(err)
	}
	var pid int
	deadline := time.Now().Add(3 * time.Second)
	for pid == 0 && time.Now().Before(deadline) {
		b, _ := os.ReadFile(pidFile)
		pid, _ = strconv.Atoi(strings.TrimSpace(string(b)))
		time.Sleep(20 * time.Millisecond)
	}
	if pid == 0 {
		t.Fatal("grandchild did not start")
	}
	t.Cleanup(func() { _ = syscall.Kill(pid, syscall.SIGKILL) })
	done := make(chan struct{})
	go func() { _ = c.Close(); close(done) }()
	select {
	case <-done:
	case <-time.After(8 * time.Second):
		t.Fatal("Close blocked on a grandchild holding the pipes")
	}
	time.Sleep(100 * time.Millisecond)
	if err := syscall.Kill(pid, 0); err == nil {
		t.Errorf("grandchild %d still alive after Close", pid)
	}
}
