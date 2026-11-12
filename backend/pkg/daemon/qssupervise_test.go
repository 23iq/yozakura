package daemon

import (
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
)

// fakeShell drives supervise without processes or real time.
type fakeShell struct {
	t        *testing.T
	mu       sync.Mutex
	now      time.Time
	pid      int
	starts   int
	failNext int // starts that fail before one succeeds
	exits    chan chan error
	delays   chan time.Duration
	fire     chan chan time.Time
	kills    chan int
	alerts   chan string
	tick     chan time.Time
	gone     bool // the compositor exited
	lost     int  // shellLost calls
}

func (f *fakeShell) lostCalls() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.lost
}

func newFakeShell(t *testing.T) (*Daemon, *fakeShell) {
	f := &fakeShell{
		t: t, now: time.Unix(1000, 0), pid: 100,
		exits: make(chan chan error, 16), delays: make(chan time.Duration, 16),
		fire: make(chan chan time.Time, 16), kills: make(chan int, 4),
		alerts: make(chan string, 4), tick: make(chan time.Time),
	}
	d := &Daemon{srv: ipc.NewServer(filepath.Join(t.TempDir(), "d.sock")), shutdownCh: make(chan struct{})}
	d.hooks = qsHooks{
		start: func(string) (<-chan error, int, error) {
			f.mu.Lock()
			defer f.mu.Unlock()
			f.starts++
			if f.failNext > 0 {
				f.failNext--
				return nil, 0, errors.New("no qs")
			}
			f.pid++
			done := make(chan error, 1)
			f.exits <- done
			return done, f.pid, nil
		},
		kill: func(pid int) { f.kills <- pid },
		now: func() time.Time {
			f.mu.Lock()
			defer f.mu.Unlock()
			return f.now
		},
		after: func(dl time.Duration) <-chan time.Time {
			c := make(chan time.Time, 1)
			f.delays <- dl
			f.fire <- c
			return c
		},
		tick:          f.tick,
		pgid:          func(pid int) (int, error) { return pid, nil },
		alert:         func(title, _ string) { f.alerts <- title },
		fallbackShell: func() string { return "fallback.qml" },
		sessionGone: func(bool) bool {
			f.mu.Lock()
			defer f.mu.Unlock()
			return f.gone
		},
		shellLost: func() {
			f.mu.Lock()
			defer f.mu.Unlock()
			f.lost++
		},
	}
	return d, f
}

func (f *fakeShell) advance(dl time.Duration) {
	f.mu.Lock()
	f.now = f.now.Add(dl)
	f.mu.Unlock()
}

func (f *fakeShell) running() chan error {
	select {
	case c := <-f.exits:
		return c
	case <-time.After(2 * time.Second):
		f.t.Fatal("shell not started")
	}
	return nil
}

func (f *fakeShell) nextDelay() (time.Duration, chan time.Time) {
	select {
	case dl := <-f.delays:
		return dl, <-f.fire
	case <-time.After(2 * time.Second):
		f.t.Fatal("no restart scheduled")
	}
	return 0, nil
}

func runSupervise(d *Daemon) (chan os.Signal, chan error) {
	sig := make(chan os.Signal, 1)
	res := make(chan error, 1)
	go func() { res <- d.supervise(sig, "shell.qml", nil) }()
	return sig, res
}

func waitResult(t *testing.T, res chan error) error {
	t.Helper()
	select {
	case err := <-res:
		return err
	case <-time.After(2 * time.Second):
		t.Fatal("supervise did not return")
	}
	return nil
}

// A crashing shell is restarted with doubling delays; past the crash-loop
// limit the daemon alerts the user and exits non-zero (releasing its
// instance lock) instead of idling without a shell.
func TestSuperviseRestartsWithBackoffThenGivesUp(t *testing.T) {
	d, f := newFakeShell(t)
	if err := d.startQS("shell.qml"); err != nil {
		t.Fatal(err)
	}
	_, res := runSupervise(d)

	want := time.Second
	for i := 0; i < CrashLoopMax; i++ {
		f.running() <- errors.New("segfault")
		dl, fire := f.nextDelay()
		if dl != want {
			t.Fatalf("restart %d after %v, want %v", i+1, dl, want)
		}
		want *= 2
		f.advance(time.Second)
		fire <- f.now
	}
	f.running() <- errors.New("segfault")
	select {
	case <-f.alerts:
	case <-time.After(2 * time.Second):
		t.Fatal("crash loop not reported")
	}
	if err := waitResult(t, res); !errors.Is(err, ErrShellCrashLoop) {
		t.Fatalf("crash loop: daemon returned %v, want ErrShellCrashLoop", err)
	}
	select {
	case <-f.delays:
		t.Fatal("restarted a crash-looping shell")
	default:
	}
	if d.qsPid.Load() != 0 {
		t.Fatal("a dead shell is still tracked")
	}
	if n := f.lostCalls(); n != 1 {
		t.Fatalf("shellLost ran %d times on a crash loop, want 1 (the polkit fallback)", n)
	}
}

// A failed start counts as an exit and is retried.
func TestSuperviseRetriesFailedStart(t *testing.T) {
	d, f := newFakeShell(t)
	if err := d.startQS("shell.qml"); err != nil {
		t.Fatal(err)
	}
	sig, res := runSupervise(d)
	f.mu.Lock()
	f.failNext = 1
	f.mu.Unlock()
	f.running() <- errors.New("crash")
	dl, fire := f.nextDelay()
	fire <- f.now
	dl2, fire2 := f.nextDelay()
	if dl != time.Second || dl2 != 2*time.Second {
		t.Fatalf("delays %v, %v", dl, dl2)
	}
	fire2 <- f.now
	f.running()
	sig <- syscall.SIGTERM
	if err := waitResult(t, res); err != nil {
		t.Fatalf("signal shutdown: %v", err)
	}
	if n := f.lostCalls(); n != 0 {
		t.Fatalf("shellLost ran on restarts and a requested shutdown (%d)", n)
	}
}

// A shell that stops sending heartbeats is killed (process group) and
// restarted; one that never sent any is left alone.
func TestSuperviseKillsFrozenShell(t *testing.T) {
	d, f := newFakeShell(t)
	if err := d.startQS("shell.qml"); err != nil {
		t.Fatal(err)
	}
	done := f.running()
	pid := int(d.qsPid.Load())
	_, res := runSupervise(d)

	tick := func() {
		f.advance(WatchdogCheck)
		f.tick <- f.now
	}
	for i := 0; i < 20; i++ {
		tick()
	}
	select {
	case <-f.kills:
		t.Fatal("killed a shell that never sent a heartbeat")
	default:
	}

	beat := func(p int) bool {
		raw, _ := json.Marshal(map[string]int{"pid": p})
		out, _ := d.heartbeat(raw)
		return out.(map[string]any)["ok"] == true
	}
	if beat(pid + 50) {
		t.Fatal("heartbeat of a foreign qs accepted")
	}
	if !beat(pid) {
		t.Fatal("heartbeat of the supervised shell refused")
	}
	for i := 0; i < int(WatchdogTimeout/WatchdogCheck)+2; i++ {
		tick()
	}
	select {
	case got := <-f.kills:
		if got != pid {
			t.Fatalf("killed %d, want %d", got, pid)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("frozen shell not killed")
	}
	done <- errors.New("killed")
	_, fire := f.nextDelay()
	fire <- f.now
	f.running()
	if int(d.qsPid.Load()) == pid {
		t.Fatal("restarted shell keeps the old pid")
	}
	d.TriggerShutdown()
	if err := waitResult(t, res); err != nil {
		t.Fatal(err)
	}
}

func TestHeartbeatWithoutShellIsRefused(t *testing.T) {
	d, _ := newFakeShell(t)
	out, err := d.heartbeat(json.RawMessage(`{"pid":5}`))
	if err != nil || out.(map[string]any)["ok"] != false {
		t.Fatalf("%v %v", out, err)
	}
}

// At logout the shell exits with the compositor: the daemon must not
// restart it (or linger holding the instance lock the next login's daemon
// needs); it shuts down cleanly instead.
func TestSuperviseStopsWhenSessionEnds(t *testing.T) {
	d, f := newFakeShell(t)
	if err := d.startQS("shell.qml"); err != nil {
		t.Fatal(err)
	}
	_, res := runSupervise(d)
	f.mu.Lock()
	f.gone = true
	f.mu.Unlock()
	f.running() <- errors.New("wayland connection lost")
	if err := waitResult(t, res); err != nil {
		t.Fatalf("session end: %v", err)
	}
	select {
	case <-f.delays:
		t.Fatal("restarted a shell after the session ended")
	default:
	}
}

// While a restart is pending no shell runs to exit at logout; the watchdog
// tick notices the compositor is gone, dialling its socket (a crashed
// compositor leaves the file behind).
func TestSuperviseTickProbesSessionWhileRestartPending(t *testing.T) {
	d, f := newFakeShell(t)
	probes := make(chan bool, 4)
	d.hooks.sessionGone = func(probe bool) bool {
		f.mu.Lock()
		defer f.mu.Unlock()
		if f.gone {
			probes <- probe
		}
		return f.gone && probe
	}
	if err := d.startQS("shell.qml"); err != nil {
		t.Fatal(err)
	}
	_, res := runSupervise(d)
	f.running() <- errors.New("segfault")
	f.nextDelay()
	f.mu.Lock()
	f.gone = true
	f.mu.Unlock()
	f.tick <- f.now
	if err := waitResult(t, res); err != nil {
		t.Fatalf("session end: %v", err)
	}
	if !<-probes {
		t.Fatal("the tick only stat'ed the socket")
	}
}

func TestWaylandGone(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", dir)
	t.Setenv("WAYLAND_DISPLAY", "")
	if waylandGone(true) {
		t.Fatal("no WAYLAND_DISPLAY: unknown, not gone")
	}
	t.Setenv("WAYLAND_DISPLAY", "wayland-9")
	if !waylandGone(false) {
		t.Fatal("missing socket file must mean gone")
	}
	ln, err := net.Listen("unix", filepath.Join(dir, "wayland-9"))
	if err != nil {
		t.Fatal(err)
	}
	if waylandGone(true) {
		t.Fatal("a listening compositor is not gone")
	}
	ln.(*net.UnixListener).SetUnlinkOnClose(false)
	_ = ln.Close()
	if waylandGone(false) {
		t.Fatal("without probing a stale socket file counts as alive")
	}
	if !waylandGone(true) {
		t.Fatal("a stale socket (crashed compositor) must mean gone")
	}
}
