package extras

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestParseStat(t *testing.T) {
	for _, c := range []struct {
		in   string
		comm string
		grp  int
		ok   bool
	}{
		{"4242 (pkexec) S 4200 4200 4200 0 -1", "pkexec", 4200, true},
		{"7 (we (ird) name) R 1 99 99 0", "we (ird) name", 99, true},
		{"7 (short) R 1", "", 0, false},
		{"garbage", "", 0, false},
	} {
		comm, grp, ok := parseStat([]byte(c.in))
		if comm != c.comm || grp != c.grp || ok != c.ok {
			t.Errorf("parseStat(%q) = %q %d %v", c.in, comm, grp, ok)
		}
	}
}

func TestPkexecWaitingFakeProc(t *testing.T) {
	proc := t.TempDir()
	write := func(pid, stat string) {
		dir := filepath.Join(proc, pid)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "stat"), []byte(stat), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("100", "100 (paru) S 1 100 100 0")
	write("101", "101 (pkexec) S 100 100 100 0")
	write("200", "200 (pkexec) S 1 200 200 0")
	write("self", "1 (pkexec) S 1 300 300 0") // not a pid
	if !pkexecWaiting(proc, 100) {
		t.Error("pkexec in group 100 not seen")
	}
	if pkexecWaiting(proc, 300) || pkexecWaiting(proc, 999) {
		t.Error("pkexec reported for a group without one")
	}
	if pkexecWaiting(filepath.Join(proc, "missing"), 100) {
		t.Error("missing proc dir reported a pkexec")
	}
}

// A process named pkexec in the command's group (here a script of that
// name: comm is the executed file's name) counts as waiting for the
// password until it is gone; the report ends with false. The script runs
// sleep as a child rather than a symlink to it (a multicall coreutils, as
// on NixOS, picks the applet by argv[0]) or an exec (that renames comm).
func TestExecRunnerRunAuthSeesPkexec(t *testing.T) {
	if _, err := exec.LookPath("sleep"); err != nil {
		t.Skip("no sleep")
	}
	dir := t.TempDir()
	fake := filepath.Join(dir, "pkexec")
	if err := os.WriteFile(fake, []byte("#!/bin/sh\nsleep \"$@\"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	old := authPoll
	authPoll = 20 * time.Millisecond
	t.Cleanup(func() { authPoll = old })

	var mu sync.Mutex
	var seen []bool
	code, err := ExecRunner{}.RunAuth(context.Background(),
		[]string{"sh", "-c", `"$1" 0.5; sleep 0.3; echo after`, "sh", fake}, nil,
		func(string) {},
		func(on bool) { mu.Lock(); seen = append(seen, on); mu.Unlock() })
	if code != 0 || err != nil {
		t.Fatalf("exit %d, %v", code, err)
	}
	mu.Lock()
	defer mu.Unlock()
	if len(seen) != 2 || !seen[0] || seen[1] {
		t.Fatalf("auth reports = %v, want [true false]", seen)
	}
}

// authFake reports the password prompt around its output, like pkexec
// before the helper runs.
type authFake struct {
	mu    sync.Mutex
	auth  int // RunAuth calls
	plain int // Run calls
}

func (f *authFake) Run(ctx context.Context, argv, env []string, line func(string)) (int, error) {
	f.mu.Lock()
	f.plain++
	f.mu.Unlock()
	return 0, nil
}

func (f *authFake) RunAuth(ctx context.Context, argv, env []string, line func(string), auth func(bool)) (int, error) {
	f.mu.Lock()
	f.auth++
	f.mu.Unlock()
	auth(true)
	auth(false)
	line("(1/1) installing a")
	return 0, nil
}

func TestQueueReportsAuthOnlyForPrivilegedJobs(t *testing.T) {
	f := &authFake{}
	r := &recorder{}
	q := NewQueue(f, r.emit, r.notify)
	q.logDir = t.TempDir()
	q.Enqueue([]Job{job("a", KindSystem, "pkexec", "y", "sys", "install", "a"), job("b", KindNpm, "npm", "b")})
	q.Wait()
	if f.auth != 1 || f.plain != 1 {
		t.Fatalf("RunAuth %d / Run %d calls, want 1 / 1", f.auth, f.plain)
	}
	var states []string
	r.mu.Lock()
	for _, p := range r.prog {
		if p.Job == "a" {
			states = append(states, p.State+map[bool]string{true: "+auth"}[p.Auth])
		}
	}
	r.mu.Unlock()
	got := strings.Join(states, ",")
	if !strings.Contains(got, "running+auth,running") {
		t.Errorf("job a progress %s: no auth on, then off, while running", got)
	}
	if fin := r.final()["a"]; fin.Auth || fin.State != JobDone {
		t.Errorf("final %+v: want done without auth", fin)
	}
}
