package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/compositor"
)

// How long polkit-fallback waits for the shell's own agent to register.
// It runs from the compositor's autostart, while the backend and the shell
// are still starting; past this the external agent starts. 12 s covers a
// cold first start (Quickshell compiles every QML file on each start, the
// config and the agent load after it, registration is asynchronous) with
// room to spare, and bounds how long a session without a working shell
// agent has none at all: a polkit request in that window fails at once
// ("no authentication agent"), it is not queued. The daemon's crash-loop
// takeover (pkg/daemon/polkitfallback.go) waits the same, so a quick
// `reload` gets the session back for the shell's agent.
const (
	polkitWait = 12 * time.Second
	polkitPoll = 250 * time.Millisecond
)

// polkitEnv is what polkit-fallback reads from the host (faked in tests).
type polkitEnv struct {
	// enabled reads system.polkitAgent from the config file.
	enabled func() bool
	// report is the shell's agent state as the daemon holds it; false when
	// no daemon answers.
	report   func() (compositor.PolkitReport, bool)
	alive    func(pid int) bool
	now      func() time.Time
	sleep    func(time.Duration)
	command  func() string
	lookPath func(string) (string, error)
	exec     func(bin string, argv []string) error
}

func defaultPolkitEnv() polkitEnv {
	return polkitEnv{
		enabled:  func() bool { return compositor.ShellAgentEnabled(paths.New().Config("system")) },
		report:   shellPolkitReport,
		alive:    pidAlive,
		now:      time.Now,
		sleep:    time.Sleep,
		command:  compositor.PolkitCommand,
		lookPath: exec.LookPath,
		exec: func(bin string, argv []string) error {
			return syscall.Exec(bin, argv, os.Environ())
		},
	}
}

// shellPolkitReport asks the running daemon what the shell last reported
// about its polkit agent (compositor.polkitState).
func shellPolkitReport() (compositor.PolkitReport, bool) {
	var r compositor.PolkitReport
	if !isAlive() {
		return r, false
	}
	res, err := newClient().Call("compositor.polkitState", nil)
	if err != nil || json.Unmarshal(res, &r) != nil {
		return compositor.PolkitReport{}, false
	}
	return r, true
}

// pidAlive reports a running process with that pid.
func pidAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	err := syscall.Kill(pid, 0)
	return err == nil || errors.Is(err, syscall.EPERM)
}

// liveReport is the daemon's report when it comes from a shell that is
// still running (a report of a shell that died says nothing about now).
func liveReport(env polkitEnv) (string, bool) {
	r, ok := env.report()
	if !ok || r.State == "" || !env.alive(r.PID) {
		return "", false
	}
	return r.State, true
}

// shellAgentHolds waits, at most polkitWait, for the shell to report its
// own agent registered. Off or unavailable (reported by the shell, or the
// setting off in the config file) ends the wait at once; no report in time
// (no daemon, no shell, a shell that crashes, a registration that never
// comes) counts as not registered.
func shellAgentHolds(env polkitEnv) bool {
	if !env.enabled() {
		return false
	}
	deadline := env.now().Add(polkitWait)
	for {
		if state, ok := liveReport(env); ok {
			switch state {
			case compositor.PolkitRegistered:
				return true
			case compositor.PolkitOff, compositor.PolkitUnavailable:
				return false
			}
		}
		if !env.now().Before(deadline) {
			return false
		}
		env.sleep(polkitPoll)
	}
}

// runPolkitFallback (`<app> polkit-fallback`, run at login by the
// compositor's startup lines, and by the shell when system.polkitAgent is
// turned off) starts the installed external polkit agent, replacing this
// process, unless the shell reports its own agent registered: two agents
// race to register and only one can. Exit 0 when the shell's agent takes
// the prompts.
func runPolkitFallback(args []string, env polkitEnv, stderr io.Writer) int {
	if len(args) > 0 {
		fmt.Fprintf(stderr, "Usage: %s\n", compositor.FallbackVerb)
		return 2
	}
	if shellAgentHolds(env) {
		return 0
	}
	argv := strings.Fields(env.command())
	if len(argv) == 0 {
		fmt.Fprintln(stderr, "polkit-fallback: no polkit agent is installed")
		return 1
	}
	bin, err := env.lookPath(argv[0])
	if err != nil {
		fmt.Fprintf(stderr, "polkit-fallback: %v\n", err)
		return 1
	}
	if err := env.exec(bin, argv); err != nil {
		fmt.Fprintf(stderr, "polkit-fallback: %v\n", err)
		return 1
	}
	return 0
}
