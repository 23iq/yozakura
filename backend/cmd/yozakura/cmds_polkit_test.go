package main

import (
	"errors"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/svc/compositor"
)

// polkitFake is a host for polkit-fallback: the setting, the daemon's
// report as it changes over (fake) time, and what was started.
type polkitFake struct {
	disabled bool
	// reports[i] is what the daemon answers on the i-th poll (the last
	// one repeats); nil means no daemon answers.
	reports []*compositor.PolkitReport
	dead    map[int]bool
	command string
	clock   time.Time
	polls   int
	ran     []string
}

func (f *polkitFake) env() polkitEnv {
	return polkitEnv{
		enabled: func() bool { return !f.disabled },
		report: func() (compositor.PolkitReport, bool) {
			if len(f.reports) == 0 {
				return compositor.PolkitReport{}, false
			}
			r := f.reports[min(f.polls, len(f.reports)-1)]
			f.polls++
			if r == nil {
				return compositor.PolkitReport{}, false
			}
			return *r, true
		},
		alive:   func(pid int) bool { return pid > 0 && !f.dead[pid] },
		now:     func() time.Time { return f.clock },
		sleep:   func(d time.Duration) { f.clock = f.clock.Add(d) },
		command: func() string { return f.command },
		lookPath: func(name string) (string, error) {
			if name == "missing" {
				return "", errors.New("not found")
			}
			if strings.HasPrefix(name, "/") {
				return name, nil
			}
			return "/usr/bin/" + name, nil
		},
		exec: func(bin string, argv []string) error {
			f.ran = append([]string{bin}, argv...)
			return nil
		},
	}
}

func rep(state string, pid int) *compositor.PolkitReport {
	return &compositor.PolkitReport{State: state, PID: pid}
}

func (f *polkitFake) run(t *testing.T) (int, time.Duration) {
	t.Helper()
	start := f.clock
	var errb strings.Builder
	code := runPolkitFallback(nil, f.env(), &errb)
	return code, f.clock.Sub(start)
}

const hyprAgent = "/usr/lib/hyprpolkitagent/hyprpolkitagent"

// The shell reports its agent registered (after a while): nothing starts.
func TestPolkitFallbackStaysOutOfTheShellAgentsWay(t *testing.T) {
	f := &polkitFake{command: hyprAgent, reports: []*compositor.PolkitReport{nil, nil, rep("pending", 7), rep("registered", 7)}}
	if code, waited := f.run(t); code != 0 || f.ran != nil || waited > time.Second {
		t.Fatalf("registered: exit %d, ran %v, waited %v", code, f.ran, waited)
	}
}

// Every way the shell's agent does not take the prompts starts the
// external one: the setting off and "off"/"unavailable" at once, no
// daemon, no shell, a stuck registration or a dead shell's report after
// the bounded wait.
func TestPolkitFallbackStartsTheExternalAgentWhenTheShellsDoesNot(t *testing.T) {
	for _, c := range []struct {
		name     string
		f        polkitFake
		maxWait  time.Duration
		minWait  time.Duration
		maxPolls int
	}{
		{name: "setting off", f: polkitFake{disabled: true, reports: []*compositor.PolkitReport{rep("registered", 7)}}, maxPolls: 0},
		{name: "shell says off", f: polkitFake{reports: []*compositor.PolkitReport{rep("off", 7)}}, maxWait: 0},
		{name: "no module", f: polkitFake{reports: []*compositor.PolkitReport{rep("pending", 7), rep("unavailable", 7)}}, maxWait: time.Second},
		{name: "no daemon", f: polkitFake{}, minWait: polkitWait},
		{name: "no shell report", f: polkitFake{reports: []*compositor.PolkitReport{rep("", 0)}}, minWait: polkitWait},
		{name: "never registers", f: polkitFake{reports: []*compositor.PolkitReport{rep("pending", 7)}}, minWait: polkitWait},
		{name: "report of a dead shell", f: polkitFake{reports: []*compositor.PolkitReport{rep("registered", 9)}, dead: map[int]bool{9: true}}, minWait: polkitWait},
	} {
		f := c.f
		f.command = hyprAgent
		code, waited := f.run(t)
		if code != 0 || strings.Join(f.ran, " ") != hyprAgent+" "+hyprAgent {
			t.Errorf("%s: exit %d, ran %v", c.name, code, f.ran)
		}
		if waited < c.minWait || (c.minWait == 0 && waited > c.maxWait) || waited > polkitWait+polkitPoll {
			t.Errorf("%s: waited %v", c.name, waited)
		}
		if c.name == "setting off" && f.polls != c.maxPolls {
			t.Errorf("%s: asked the daemon %d times", c.name, f.polls)
		}
	}
}

func TestPolkitFallbackStartsTheInstalledAgent(t *testing.T) {
	f := &polkitFake{disabled: true, command: "systemctl --user start hyprpolkitagent"}
	if code, _ := f.run(t); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if got := strings.Join(f.ran, " "); got != "/usr/bin/systemctl systemctl --user start hyprpolkitagent" {
		t.Fatalf("ran %q", got)
	}
}

func TestPolkitFallbackFailures(t *testing.T) {
	for _, c := range []struct {
		args    []string
		command string
		code    int
	}{
		{nil, "", 1},
		{nil, "missing --flag", 1},
		{[]string{"extra"}, "/x/agent", 2},
	} {
		f := &polkitFake{disabled: true, command: c.command}
		var errb strings.Builder
		if code := runPolkitFallback(c.args, f.env(), &errb); code != c.code || f.ran != nil || errb.Len() == 0 {
			t.Errorf("%v %q: exit %d (want %d), ran %v, stderr %q", c.args, c.command, code, c.code, f.ran, errb.String())
		}
	}
}

func TestBootstrapStartsTheFallbackVerb(t *testing.T) {
	argv := []string{"/opt/bin/yozakura", "polkit-fallback"}
	niri := bootstrapBody(niriConfig, "/opt/bin/yozakura", argv)
	if !strings.Contains(niri, `spawn-at-startup "/opt/bin/yozakura" "polkit-fallback"`+"\n") {
		t.Fatalf("niri bootstrap:\n%s", niri)
	}
	mango := bootstrapBody(mangoConfig, "/opt/bin/yozakura", argv)
	if !strings.Contains(mango, "exec-once = /opt/bin/yozakura polkit-fallback\n") {
		t.Fatalf("mango bootstrap:\n%s", mango)
	}
	// A launcher path with a space stays one argument / one sh word.
	spaced := []string{"/home/a b/bin/yozakura", "polkit-fallback"}
	if niri := bootstrapBody(niriConfig, spaced[0], spaced); !strings.Contains(niri, `spawn-at-startup "/home/a b/bin/yozakura" "polkit-fallback"`+"\n") {
		t.Fatalf("niri bootstrap with a space:\n%s", niri)
	}
	if mango := bootstrapBody(mangoConfig, spaced[0], spaced); !strings.Contains(mango, "exec-once = '/home/a b/bin/yozakura' polkit-fallback\n") {
		t.Fatalf("mango bootstrap with a space:\n%s", mango)
	}
	if body := bootstrapBody(mangoConfig, "/opt/bin/yozakura", nil); strings.Contains(body, "polkit") {
		t.Fatalf("no external agent: no polkit line:\n%s", body)
	}
}
