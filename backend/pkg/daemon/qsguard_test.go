package daemon

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"testing"
	"time"
)

// The shell's heartbeat timer (BackendService.qml) beats at
// HeartbeatInterval; a slower one would trip the watchdog.
func TestShellHeartbeatMatchesInterval(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "..", "..", "modules", "services", "BackendService.qml"))
	if err != nil {
		t.Fatal(err)
	}
	m := regexp.MustCompile(`id: heartbeatTimer\s+interval: (\d+)`).FindSubmatch(src)
	if m == nil {
		t.Fatal("heartbeatTimer interval not found in BackendService.qml")
	}
	ms, _ := strconv.Atoi(string(m[1]))
	if time.Duration(ms)*time.Millisecond != HeartbeatInterval {
		t.Fatalf("shell beats every %d ms, HeartbeatInterval is %v", ms, HeartbeatInterval)
	}
}

func TestCrashGuardBackoffAndCrashLoop(t *testing.T) {
	var g crashGuard
	now := time.Unix(1000, 0)
	want := []time.Duration{1 * time.Second, 2 * time.Second, 4 * time.Second, 8 * time.Second, 16 * time.Second}
	for i, w := range want {
		d, giveUp := g.record(now)
		if giveUp || d != w {
			t.Fatalf("exit %d: delay %v giveUp %v, want %v", i+1, d, giveUp, w)
		}
		now = now.Add(time.Second)
	}
	if _, giveUp := g.record(now); !giveUp {
		t.Fatalf("exit %d inside %v must be a crash loop", CrashLoopMax+1, CrashWindow)
	}
}

// Exits older than CrashWindow do not count: a shell that ran for a while
// starts over at the base delay and never trips the crash-loop guard.
func TestCrashGuardWindowSlides(t *testing.T) {
	var g crashGuard
	now := time.Unix(1000, 0)
	for i := 0; i < 20; i++ {
		d, giveUp := g.record(now)
		if giveUp || d != RestartBaseDelay {
			t.Fatalf("exit %d after a stable minute: delay %v giveUp %v", i, d, giveUp)
		}
		now = now.Add(CrashWindow + time.Second)
	}
}

func TestSupervisionThresholdsConsistent(t *testing.T) {
	if RestartBaseDelay<<(CrashLoopMax-1) > RestartMaxDelay*2 {
		t.Fatalf("the cap hides most of the backoff steps")
	}
	if WatchdogTimeout < 3*HeartbeatInterval {
		t.Fatalf("watchdog %v must allow several missed heartbeats (%v)", WatchdogTimeout, HeartbeatInterval)
	}
	if WatchdogCheck >= WatchdogTimeout {
		t.Fatalf("watchdog check %v must be shorter than its timeout %v", WatchdogCheck, WatchdogTimeout)
	}
}

// tickUntil checks the watchdog every WatchdogCheck from now for d and
// reports whether it expired.
func tickUntil(w *watchdog, now time.Time, d time.Duration) (time.Time, bool) {
	end := now.Add(d)
	for now.Before(end) {
		now = now.Add(WatchdogCheck)
		if w.expired(now) {
			return now, true
		}
	}
	return now, false
}

func TestWatchdogArmsOnFirstHeartbeat(t *testing.T) {
	var w watchdog
	now := time.Unix(1000, 0)
	if _, exp := tickUntil(&w, now, 10*WatchdogTimeout); exp {
		t.Fatal("a shell that never sent a heartbeat must not be killed")
	}
	now = now.Add(10 * WatchdogTimeout)
	w.beat(now)
	now2, exp := tickUntil(&w, now, WatchdogTimeout-WatchdogCheck)
	if exp {
		t.Fatal("expired before the timeout")
	}
	w.beat(now2)
	at, exp := tickUntil(&w, now2, 2*WatchdogTimeout)
	if !exp {
		t.Fatal("a silent shell must expire")
	}
	if late := at.Sub(now2); late <= WatchdogTimeout || late > WatchdogTimeout+WatchdogCheck {
		t.Fatalf("expired after %v, want just past %v", late, WatchdogTimeout)
	}
	w.disarm()
	if _, exp := tickUntil(&w, at, 2*WatchdogTimeout); exp {
		t.Fatal("disarmed watchdog expired")
	}
}

// A long gap between checks (suspend, stopped daemon) restarts the grace
// period instead of killing a shell that could not run either.
func TestWatchdogGraceAfterSuspend(t *testing.T) {
	var w watchdog
	now := time.Unix(1000, 0)
	w.beat(now)
	now = now.Add(WatchdogCheck)
	if w.expired(now) {
		t.Fatal("fresh heartbeat expired")
	}
	now = now.Add(time.Hour)
	if w.expired(now) {
		t.Fatal("killed right after resume")
	}
	if _, exp := tickUntil(&w, now, WatchdogTimeout-WatchdogCheck); exp {
		t.Fatal("grace period too short")
	}
}
