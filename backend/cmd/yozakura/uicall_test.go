package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"yozakura/backend/pkg/svc"
)

// fakeUI simulates a daemon that is down until started and needs a few
// polls before it answers.
type fakeUI struct {
	alive      bool
	answering  bool
	readyAfter int // polls between start and answering
	startDead  bool
	starts     int
	locks      int
	calls      []string
	terminals  int
	result     string
	now        time.Time
	slept      time.Duration
	noWayland  bool
	// shellAfter: polls until a shell subscribes (0: none ever does)
	shellAfter int
	shells     int
	// dieAfter: ui.shells polls before the daemon exits (gave up)
	dieAfter int
}

func (f *fakeUI) env() uiEnv {
	return uiEnv{
		alive:   func() bool { return f.alive },
		wayland: func() bool { return !f.noWayland },
		call: func(m string, p any) (json.RawMessage, error) {
			b, _ := json.Marshal(p)
			f.calls = append(f.calls, m+" "+string(b))
			if !f.answering {
				return nil, errors.New("dial: no such file")
			}
			if m == "ui.shells" {
				if f.dieAfter > 0 {
					f.dieAfter--
					if f.dieAfter == 0 {
						f.alive, f.answering = false, false
						f.result = "ok" // the fresh daemon's shell takes it
						f.readyAfter = 2
					}
				}
				return json.Marshal(f.shells)
			}
			res := f.result
			if res == "" {
				res = "ok"
			}
			return json.RawMessage(`"` + res + `"`), nil
		},
		start: func() {
			f.starts++
			if !f.startDead {
				f.alive = true
			}
		},
		starting: func() func() { f.locks++; return func() {} },
		terminal: func() error { f.terminals++; return nil },
		sleep: func(d time.Duration) {
			f.slept += d
			f.now = f.now.Add(d)
			if f.alive && f.readyAfter > 0 {
				f.readyAfter--
				if f.readyAfter == 0 {
					f.answering = true
				}
			}
			if f.shellAfter > 0 {
				f.shellAfter--
				if f.shellAfter == 0 {
					f.shells = 1
				}
			}
		},
		now: func() time.Time { return f.now },
	}
}

func TestRunUIStartsDeadDaemonAndRetries(t *testing.T) {
	f := &fakeUI{now: time.Unix(0, 0), readyAfter: 3}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "launcher", f.env(), &errOut); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	if f.starts != 1 || f.locks != 1 {
		t.Fatalf("starts %d locks %d, want one start under the lock", f.starts, f.locks)
	}
	if last := f.calls[len(f.calls)-1]; last != `ui.run {"command":"launcher"}` {
		t.Fatalf("last call %q", last)
	}
}

func TestRunUILiveDaemonIsNotRestarted(t *testing.T) {
	f := &fakeUI{alive: true, answering: true}
	if code := runUI("ui.toggle", "bar", f.env(), &bytes.Buffer{}); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if f.starts != 0 || f.locks != 0 || len(f.calls) != 1 {
		t.Fatalf("starts %d locks %d calls %v", f.starts, f.locks, f.calls)
	}
}

// A daemon that never comes up ends the wait with an error, bounded.
func TestRunUIGivesUpAfterBoundedWait(t *testing.T) {
	f := &fakeUI{now: time.Unix(0, 0), startDead: true}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "lockscreen", f.env(), &errOut); code != 1 {
		t.Fatalf("exit %d", code)
	}
	if f.slept < uiStartWait || f.slept > uiStartWait+uiPoll {
		t.Fatalf("waited %v, want about %v", f.slept, uiStartWait)
	}
	if f.starts != 1 || errOut.Len() == 0 {
		t.Fatalf("starts %d, err %q", f.starts, errOut.String())
	}
}

// A daemon that is up but never answers: bounded retry, no second start.
func TestRunUIAliveButSilentDaemon(t *testing.T) {
	f := &fakeUI{alive: true, now: time.Unix(0, 0)}
	if code := runUI("ui.run", "dashboard", f.env(), &bytes.Buffer{}); code != 1 {
		t.Fatalf("exit %d", code)
	}
	if f.starts != 0 {
		t.Fatalf("started a second daemon next to a live one")
	}
}

func TestRunTerminalWithoutDaemonOpensItDirectly(t *testing.T) {
	f := &fakeUI{}
	if code := runUI("ui.run", "terminal", f.env(), &bytes.Buffer{}); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if f.terminals != 1 || f.starts != 0 || len(f.calls) != 0 {
		t.Fatalf("terminals %d starts %d calls %v", f.terminals, f.starts, f.calls)
	}
}

func TestRunTerminalGoesThroughALiveShell(t *testing.T) {
	f := &fakeUI{alive: true, answering: true}
	if code := runUI("ui.run", "terminal", f.env(), &bytes.Buffer{}); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if f.terminals != 0 || len(f.calls) != 1 || f.calls[0] != `ui.run {"command":"terminal","noQueue":true}` {
		t.Fatalf("terminals %d calls %v", f.terminals, f.calls)
	}
}

// Daemon up, shell crashed (nobody received it): open it directly.
func TestRunTerminalWithoutShellOpensItDirectly(t *testing.T) {
	for _, f := range []*fakeUI{
		{alive: true, answering: true, result: "undelivered"},
		{alive: true},
	} {
		if code := runUI("ui.run", "terminal", f.env(), &bytes.Buffer{}); code != 0 || f.terminals != 1 {
			t.Fatalf("exit %d terminals %d", code, f.terminals)
		}
	}
}

// A command only queued (no shell yet) succeeds but says so.
func TestRunUIReportsQueuedCommand(t *testing.T) {
	f := &fakeUI{alive: true, answering: true, result: "queued"}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "launcher", f.env(), &errOut); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if !bytes.Contains(errOut.Bytes(), []byte("queued")) {
		t.Fatalf("no note for a queued command: %q", errOut.String())
	}
	errOut.Reset()
	f = &fakeUI{alive: true, answering: true}
	runUI("ui.run", "lockscreen", f.env(), &errOut)
	if errOut.Len() != 0 {
		t.Fatalf("delivered command printed %q", errOut.String())
	}
}

// Outside a Wayland session (SSH, cron) no daemon is started: it could
// not show a shell and would hold the next login's instance lock.
func TestRunUIRefusesToStartWithoutWayland(t *testing.T) {
	f := &fakeUI{now: time.Unix(0, 0), noWayland: true}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "lockscreen", f.env(), &errOut); code != 1 {
		t.Fatalf("exit %d", code)
	}
	if f.starts != 0 || !bytes.Contains(errOut.Bytes(), []byte("WAYLAND_DISPLAY")) {
		t.Fatalf("starts %d err %q", f.starts, errOut.String())
	}
	// a running daemon is still used
	f = &fakeUI{alive: true, answering: true, noWayland: true}
	if code := runUI("ui.toggle", "bar", f.env(), &bytes.Buffer{}); code != 0 {
		t.Fatalf("live daemon without WAYLAND_DISPLAY: exit %d", code)
	}
}

// A queued `lock` succeeds only once a shell picked it up: hypridle's
// before_sleep_cmd suspends as soon as it returns.
func TestRunLockWaitsForAShell(t *testing.T) {
	f := &fakeUI{alive: true, answering: true, result: "queued", now: time.Unix(0, 0), shellAfter: 5}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "lockscreen", f.env(), &errOut); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	if f.calls[0] != `ui.run {"command":"lockscreen"}` || f.calls[len(f.calls)-1] != "ui.shells null" {
		t.Fatalf("calls %v", f.calls)
	}
}

func TestRunLockFailsWhenNoShellComes(t *testing.T) {
	f := &fakeUI{alive: true, answering: true, result: "queued", now: time.Unix(0, 0)}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "lockscreen", f.env(), &errOut); code != 1 {
		t.Fatalf("exit %d", code)
	}
	if f.slept >= svc.UIPendingTTL {
		t.Fatalf("waited %v, past the queued command's %v lifetime", f.slept, svc.UIPendingTTL)
	}
	if errOut.Len() == 0 {
		t.Fatal("no error for a lock that did not happen")
	}
}

// The daemon gave up on a crash-looping shell and exited while `lock`
// waited: a fresh daemon (fresh crash guard, new shell) gets the lock.
func TestRunLockRestartsADaemonThatGaveUp(t *testing.T) {
	f := &fakeUI{alive: true, answering: true, result: "queued", now: time.Unix(0, 0), dieAfter: 2}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "lockscreen", f.env(), &errOut); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	if f.starts != 1 {
		t.Fatalf("starts %d, want the dead daemon started again", f.starts)
	}
	if last := f.calls[len(f.calls)-1]; last != `ui.run {"command":"lockscreen"}` {
		t.Fatalf("last call %q", last)
	}
}
