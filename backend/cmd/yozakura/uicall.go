package main

import (
	"encoding/json"
	"fmt"
	"io"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/instancelock"
	"yozakura/backend/pkg/svc"
)

// How long `run`/`toggle`/`lock` wait for a daemon they started (or one a
// concurrent reload is starting) before giving up.
const (
	uiStartWait = 10 * time.Second
	uiPoll      = 100 * time.Millisecond
)

// uiEnv is what the shell commands (`run`, `toggle`, `lock`, `onboarding`)
// need from the system; tests swap it.
type uiEnv struct {
	alive func() bool
	call  func(method string, params any) (json.RawMessage, error)
	// start launches the daemon detached; its instance lock keeps a second
	// one from ever coming up.
	start func()
	// starting serialises CLI starters with `reload` (the reload lock) and
	// returns its release.
	starting func() func()
	// terminal opens the configured terminal without the shell.
	terminal func() error
	sleep    func(time.Duration)
	now      func() time.Time
}

func defaultUIEnv() uiEnv {
	return uiEnv{
		alive: isAlive,
		call:  func(m string, p any) (json.RawMessage, error) { return newClient().Call(m, p) },
		start: startDaemon,
		starting: func() func() {
			l, err := instancelock.TryAcquire(instancelock.ReloadPath())
			if err != nil {
				// a reload (or another starter) is at it: wait for it
				instancelock.WaitFree(instancelock.ReloadPath(), startWait)
				return func() {}
			}
			return l.Release
		},
		terminal: openTerminalDirect,
		sleep:    time.Sleep,
		now:      time.Now,
	}
}

// openTerminalDirect starts general.terminal like the shell's
// TerminalService.open does (one argv element, no shell).
func openTerminalDirect() error {
	return startDetached([]string{storedTerminalConfig().Terminal})
}

// runUI sends a UI command (method ui.run or ui.toggle) to the shell. With
// the daemon down it starts it and retries; `run terminal` opens the
// terminal itself when no shell would receive it, so a crashed shell never
// costs the user their terminal.
func runUI(method, command string, env uiEnv, errOut io.Writer) int {
	if method == "ui.run" && command == "terminal" {
		return runUITerminal(env, errOut)
	}
	params := map[string]any{"command": command}
	if env.alive() {
		if res, err := env.call(method, params); err == nil {
			noteQueued(res, command, errOut)
			return 0
		}
	}
	if err := ensureDaemon(env); err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	deadline := env.now().Add(uiStartWait)
	for {
		res, err := env.call(method, params)
		if err == nil {
			noteQueued(res, command, errOut)
			return 0
		}
		if !env.now().Before(deadline) {
			fmt.Fprintf(errOut, "Error: %v\n", err)
			return 1
		}
		env.sleep(uiPoll)
	}
}

// runUITerminal asks a live shell to open the terminal (never queued) and
// opens it directly when there is no daemon or no shell listening.
func runUITerminal(env uiEnv, errOut io.Writer) int {
	if env.alive() {
		res, err := env.call("ui.run", map[string]any{"command": "terminal", "noQueue": true})
		var status string
		if err == nil && (json.Unmarshal(res, &status) != nil || status != svc.UIUndelivered) {
			return 0
		}
	}
	if err := env.terminal(); err != nil {
		fmt.Fprintf(errOut, "Error: cannot open the terminal: %v\n", err)
		return 1
	}
	return 0
}

// ensureDaemon starts the daemon unless one runs (or a concurrent reload
// brings one up) and waits until it holds its instance lock.
func ensureDaemon(env uiEnv) error {
	if env.alive() {
		return nil
	}
	release := env.starting()
	defer release()
	if !env.alive() {
		env.start()
	}
	deadline := env.now().Add(uiStartWait)
	for !env.alive() {
		if !env.now().Before(deadline) {
			return fmt.Errorf("the %s daemon is not running and did not start; run `%s` to see why", brand.DisplayName, brand.AppID)
		}
		env.sleep(uiPoll)
	}
	return nil
}

// noteQueued tells the caller that no shell received the command yet (it
// is restarting, or gave up after a crash loop): a `lock` that only got
// queued has not locked anything.
func noteQueued(res json.RawMessage, command string, errOut io.Writer) {
	var status string
	if json.Unmarshal(res, &status) == nil && status == svc.UIQueued {
		fmt.Fprintf(errOut, "Note: the shell is not running; %q is queued for %v (run `%s reload` if it does not come back)\n",
			command, svc.UIPendingTTL, brand.AppID)
	}
}
