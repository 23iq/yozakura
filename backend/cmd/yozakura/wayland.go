package main

import (
	"fmt"
	"os"

	"yozakura/backend/pkg/brand"
)

// A daemon started outside a Wayland session (SSH, cron, a TTY) cannot
// show a shell, yet it would hold the instance lock the next login's
// daemon needs: that one would exit "already running" and the user gets no
// shell. Every path that starts a daemon checks for a session first.

// haveWayland reports whether this process runs inside a Wayland session.
func haveWayland() bool { return os.Getenv("WAYLAND_DISPLAY") != "" }

// refuseWithoutWayland exits 1 with why() outside a Wayland session.
func refuseWithoutWayland(why func() error) {
	if !haveWayland() {
		fmt.Fprintf(os.Stderr, "Error: %v\n", why())
		os.Exit(1)
	}
}

// errNoWayland is why `run`/`toggle`/`lock` start no daemon.
func errNoWayland() error {
	return fmt.Errorf("the %s daemon is not running and WAYLAND_DISPLAY is unset (not in a Wayland session, e.g. over SSH or from cron); not starting it here",
		brand.DisplayName)
}

// errNoWaylandStart is why the bare command does not become the daemon.
func errNoWaylandStart() error {
	return fmt.Errorf("WAYLAND_DISPLAY is unset (not in a Wayland session); %s is started by the compositor (exec-once / spawn-at-startup)",
		brand.DisplayName)
}

// errNoWaylandReload is why `reload` leaves the running daemon alone.
func errNoWaylandReload() error {
	return fmt.Errorf("WAYLAND_DISPLAY is unset (not in a Wayland session); a reload from here could not start %s again, so the running one is left alone",
		brand.DisplayName)
}
