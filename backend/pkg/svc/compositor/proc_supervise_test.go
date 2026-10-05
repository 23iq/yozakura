package compositor

import (
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
	"yozakura/backend/pkg/brand"
)

// fakeDaemon puts a stand-in yozd on PATH (every subcommand just sleeps) and
// points XDG_RUNTIME_DIR at a temp dir holding a live yozd.sock, so the
// Manager can be exercised without the real compositor.
func fakeDaemon(t *testing.T) string {
	t.Helper()
	bin := t.TempDir()
	script := "#!/bin/sh\nexec sleep 300\n"
	if err := os.WriteFile(filepath.Join(bin, brand.Daemon), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	runtime := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtime)
	ln, err := net.Listen("unix", filepath.Join(runtime, brand.Daemon+".sock"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ln.Close() })
	return filepath.Join(t.TempDir(), brand.DaemonConfigFile())
}

type tomlPath string

func (p tomlPath) DaemonToml() string { return string(p) }

// procState returns the /proc state letter of pid ("" when it is gone).
func procState(pid int) string {
	data, err := os.ReadFile("/proc/" + strconv.Itoa(pid) + "/stat")
	if err != nil {
		return ""
	}
	s := string(data)
	i := strings.LastIndexByte(s, ')')
	if i < 0 || i+2 >= len(s) {
		return ""
	}
	return s[i+2 : i+3]
}

func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

// An yozd daemon killed from outside (a stray pkill from a previous
// instance's teardown during `reload`) must be reaped, not left as a
// zombie, and restarted so the shell keeps a working compositor socket.
func TestManagerReapsAndRestartsKilledDaemon(t *testing.T) {
	m := NewManager(tomlPath(fakeDaemon(t)))
	if err := m.Start(); err != nil {
		t.Fatal(err)
	}
	defer m.Close()

	first := m.daemonPID()
	if first <= 0 {
		t.Fatal("daemon not started")
	}
	if err := syscall.Kill(first, syscall.SIGKILL); err != nil {
		t.Fatal(err)
	}

	waitFor(t, "killed daemon to be reaped", func() bool { return procState(first) == "" })
	waitFor(t, "daemon restart", func() bool {
		pid := m.daemonPID()
		return pid > 0 && pid != first && procState(pid) != ""
	})

	second := m.daemonPID()
	m.Close()
	if st := procState(second); st != "" {
		t.Fatalf("restarted daemon still present after Close (state %q)", st)
	}
}

// Close must not trigger a restart: after it returns no yozd daemon is
// left running or zombied.
func TestManagerCloseStopsSupervision(t *testing.T) {
	m := NewManager(tomlPath(fakeDaemon(t)))
	if err := m.Start(); err != nil {
		t.Fatal(err)
	}
	pid := m.daemonPID()
	m.Close()
	if st := procState(pid); st != "" {
		t.Fatalf("daemon left behind after Close (state %q)", st)
	}
	time.Sleep(daemonRestartDelay + 200*time.Millisecond)
	if p := m.daemonPID(); p != 0 {
		t.Fatalf("daemon restarted after Close (pid %d)", p)
	}
}
