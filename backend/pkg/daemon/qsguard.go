package daemon

import (
	"sync"
	"time"
)

// Quickshell restart policy. A shell that exits on its own (crash, OOM
// kill, watchdog kill) is started again after RestartBaseDelay, doubling
// with every further exit inside CrashWindow up to RestartMaxDelay. More
// than CrashLoopMax exits inside CrashWindow is a crash loop: the daemon
// stops restarting, stays up (IPC, yozd, clipboard keep working) and tells
// the user how to recover.
const (
	RestartBaseDelay = 1 * time.Second
	RestartMaxDelay  = 16 * time.Second
	CrashWindow      = 60 * time.Second
	CrashLoopMax     = 5
)

// Freeze watchdog. The shell sends system.heartbeat every
// HeartbeatInterval from its GUI thread (BackendService.qml); once the
// first one arrived, WatchdogTimeout without one means the GUI thread is
// stuck and the shell's process group is killed (then restarted like a
// crash). The daemon checks every WatchdogCheck.
const (
	HeartbeatInterval = 3 * time.Second
	WatchdogTimeout   = 15 * time.Second
	WatchdogCheck     = 2 * time.Second
)

// crashGuard decides how long to wait before restarting the shell and
// when to give up. Only exits inside the sliding CrashWindow count, so a
// shell that stayed up for a minute starts over at RestartBaseDelay.
type crashGuard struct {
	exits []time.Time
}

// record notes an exit at now. It returns the delay before the next start,
// or giveUp when the shell is crash looping.
func (g *crashGuard) record(now time.Time) (delay time.Duration, giveUp bool) {
	cut := now.Add(-CrashWindow)
	kept := g.exits[:0]
	for _, t := range g.exits {
		if t.After(cut) {
			kept = append(kept, t)
		}
	}
	g.exits = append(kept, now)
	n := len(g.exits)
	if n > CrashLoopMax {
		return 0, true
	}
	delay = RestartBaseDelay
	for i := 1; i < n && delay < RestartMaxDelay; i++ {
		delay *= 2
	}
	if delay > RestartMaxDelay {
		delay = RestartMaxDelay
	}
	return delay, false
}

// watchdog tracks the shell's heartbeats. It stays disarmed until the
// first heartbeat of the current shell, so a slow start (or a shell from
// before the heartbeat existed) is never killed.
type watchdog struct {
	mu        sync.Mutex
	armed     bool
	last      time.Time // last heartbeat (or grace start)
	lastCheck time.Time
}

// beat records a heartbeat of the current shell.
func (w *watchdog) beat(now time.Time) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.armed = true
	w.last = now
}

// disarm forgets the shell (a new one is starting or none runs).
func (w *watchdog) disarm() {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.armed = false
	w.last = time.Time{}
	w.lastCheck = time.Time{}
}

// expired reports whether the shell missed its heartbeats for
// WatchdogTimeout. A check that itself comes much later than WatchdogCheck
// (the machine was suspended, the daemon was stopped) restarts the grace
// period instead: the shell could not beat while nothing ran.
func (w *watchdog) expired(now time.Time) bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	prev := w.lastCheck
	w.lastCheck = now
	if !w.armed {
		return false
	}
	if !prev.IsZero() && now.Sub(prev) > 2*WatchdogCheck+time.Second {
		w.last = now
		return false
	}
	return now.Sub(w.last) > WatchdogTimeout
}
