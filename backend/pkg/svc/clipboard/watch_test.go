package clipboard

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestNextWatchDelay(t *testing.T) {
	short := time.Second
	d := nextWatchDelay(0, short)
	if d != watchBackoffMin {
		t.Fatalf("first delay = %v, want %v", d, watchBackoffMin)
	}
	for i := 0; i < 20; i++ {
		next := nextWatchDelay(d, short)
		if next < d || next > watchBackoffMax {
			t.Fatalf("delay %v -> %v outside [prev, max]", d, next)
		}
		d = next
	}
	if d != watchBackoffMax {
		t.Fatalf("delay after repeated quick exits = %v, want cap %v", d, watchBackoffMax)
	}
	if got := nextWatchDelay(d, watchHealthyRun); got != watchBackoffMin {
		t.Fatalf("delay after a healthy run = %v, want reset to %v", got, watchBackoffMin)
	}
}

// fakeWlPaste puts a wl-paste on PATH running body (sh); it can append to
// the file in $COUNT to record calls.
func fakeWlPaste(t *testing.T, body string) string {
	t.Helper()
	bin := t.TempDir()
	count := filepath.Join(t.TempDir(), "calls")
	script := "#!/bin/sh\n" + body + "\n"
	if err := os.WriteFile(filepath.Join(bin, "wl-paste"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("COUNT", count)
	return count
}

// A wl-paste that exits immediately is respawned with a growing delay,
// not in a tight loop, and stop still ends the loop at once.
func TestWatcherBacksOffWhenWlPasteExits(t *testing.T) {
	count := fakeWlPaste(t, `echo x >> "$COUNT"; exit 1`)
	oldMin, oldMax := watchBackoffMin, watchBackoffMax
	watchBackoffMin, watchBackoffMax = 50*time.Millisecond, 400*time.Millisecond
	t.Cleanup(func() { watchBackoffMin, watchBackoffMax = oldMin, oldMax })

	w := &watchProc{svc: NewService(testPaths(t)), stopCh: make(chan struct{})}
	done := make(chan struct{})
	go func() { w.run(); close(done) }()
	time.Sleep(1500 * time.Millisecond)
	w.stop()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("watcher did not stop")
	}

	data, _ := os.ReadFile(count)
	spawns := strings.Count(string(data), "x")
	// 0, 50, 150, 350, 750 ms (then 400 ms steps): about 6 runs in 1.5 s;
	// without backoff it is hundreds.
	if spawns < 2 || spawns > 10 {
		t.Fatalf("wl-paste spawned %d times in 1.5 s", spawns)
	}
}
