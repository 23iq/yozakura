package compositor

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/yozd/client"
)

func TestRestartPolicyBacksOffAndCaps(t *testing.T) {
	var p restartPolicy
	want := []time.Duration{500 * time.Millisecond, time.Second, 2 * time.Second, 4 * time.Second,
		8 * time.Second, 16 * time.Second, 30 * time.Second, 30 * time.Second}
	for i, w := range want {
		if d, first := p.next(0, false); d != w || first {
			t.Fatalf("exit %d: delay %v first %v, want %v false", i+1, d, first, w)
		}
	}
}

func TestRestartPolicyResetsAfterHealthyRun(t *testing.T) {
	var p restartPolicy
	for range 5 {
		p.next(time.Second, false)
	}
	if d, _ := p.next(daemonHealthyRun, false); d != daemonRestartDelay {
		t.Fatalf("after a healthy run: %v, want %v", d, daemonRestartDelay)
	}
}

func TestRestartPolicyNoCompositorGoesSlow(t *testing.T) {
	var p restartPolicy
	var got []time.Duration
	var firsts int
	for range 7 {
		d, first := p.next(0, true)
		got = append(got, d)
		if first {
			firsts++
		}
	}
	want := []time.Duration{500 * time.Millisecond, time.Second, time.Minute, 2 * time.Minute,
		4 * time.Minute, 5 * time.Minute, 5 * time.Minute}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("no-compositor delays %v, want %v", got, want)
		}
	}
	if firsts != 1 {
		t.Fatalf("first reported %d times, want once per streak", firsts)
	}
	// another kind of exit ends the streak: back to the normal cap
	if d, _ := p.next(0, false); d != daemonRestartMax {
		t.Fatalf("after the streak: %v, want %v", d, daemonRestartMax)
	}
	if _, first := p.next(0, true); !first {
		t.Fatal("a new streak is reported again")
	}
}

// A yozd that finds no compositor (it exits ExitNoCompositor at once) is
// no longer restarted every 500 ms: a few quick tries, then the slow
// interval, and one log line instead of one per restart.
func TestManagerBacksOffWhenNoCompositor(t *testing.T) {
	setVar(t, &daemonRestartDelay, 10*time.Millisecond)
	setVar(t, &noCompositorRetry, 300*time.Millisecond)
	setVar(t, &noCompositorMax, 300*time.Millisecond)
	var logMu sync.Mutex
	var logs []string
	oldLog := logf
	logf = func(format string, args ...any) {
		logMu.Lock()
		logs = append(logs, fmt.Sprintf(format, args...))
		logMu.Unlock()
	}
	t.Cleanup(func() { logf = oldLog })

	starts := filepath.Join(t.TempDir(), "starts")
	bin := t.TempDir()
	script := "#!/bin/sh\necho x >> \"$YOZD_TEST_STARTS\"\nexit " + strconv.Itoa(client.ExitNoCompositor) + "\n"
	if err := os.WriteFile(filepath.Join(bin, brand.Daemon), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	t.Setenv("YOZD_TEST_STARTS", starts)

	m := NewManager(tomlPath(filepath.Join(t.TempDir(), brand.DaemonConfigFile())))
	if err := m.Start(); err != nil {
		t.Fatal(err)
	}
	time.Sleep(time.Second)
	m.Close()

	data, _ := os.ReadFile(starts)
	n := strings.Count(string(data), "x")
	// 0, +10 ms, +20 ms (third exit: slow from now on), then every 300 ms:
	// 5 or 6 starts in a second; a fixed 10 ms delay would give ~100
	if n < 4 || n > 7 {
		t.Fatalf("%d starts in 1s, want 4..7", n)
	}
	logMu.Lock()
	defer logMu.Unlock()
	noComp := 0
	for _, l := range logs {
		if strings.Contains(l, "no supported compositor") {
			noComp++
		} else {
			t.Errorf("unexpected log line %q", l)
		}
	}
	if noComp != 1 {
		t.Fatalf("logged %d times, want once: %q", noComp, logs)
	}
}

func setVar[T any](t *testing.T, v *T, val T) {
	t.Helper()
	old := *v
	*v = val
	t.Cleanup(func() { *v = old })
}
