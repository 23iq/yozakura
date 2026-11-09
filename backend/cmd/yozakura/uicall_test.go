package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"
	"time"
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
}

func (f *fakeUI) env() uiEnv {
	return uiEnv{
		alive: func() bool { return f.alive },
		call: func(m string, p any) (json.RawMessage, error) {
			b, _ := json.Marshal(p)
			f.calls = append(f.calls, m+" "+string(b))
			if !f.answering {
				return nil, errors.New("dial: no such file")
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

// A command only queued (no shell yet) succeeds but says so: a `lock`
// that nothing received has not locked the screen.
func TestRunUIReportsQueuedCommand(t *testing.T) {
	f := &fakeUI{alive: true, answering: true, result: "queued"}
	var errOut bytes.Buffer
	if code := runUI("ui.run", "lockscreen", f.env(), &errOut); code != 0 {
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
