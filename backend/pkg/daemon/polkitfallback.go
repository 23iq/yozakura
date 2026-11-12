package daemon

import (
	"context"
	"log"
	"os"
	"syscall"

	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/proc"
	"yozakura/backend/pkg/svc/compositor"
)

// polkitTakeover hands the session's polkit prompts to the external agent
// once the daemon stops restarting the shell for good (crash loop): when
// the shell's own agent held the session (its last report: registered),
// nothing would answer a prompt until the next login. It runs `<launcher>
// polkit-fallback` (the login path: it starts the external agent unless a
// shell registers its own again in time, e.g. after a quick `reload`).
// Any other report means another agent holds the session, or the startup
// line's fallback already ran: nothing is started. Reports whether it
// spawned.
func polkitTakeover(r compositor.PolkitReport, launcher string, spawn func(argv []string) error) bool {
	if r.State != compositor.PolkitRegistered || launcher == "" {
		return false
	}
	if err := spawn([]string{launcher, compositor.FallbackVerb}); err != nil {
		log.Printf("[yozakura] polkit fallback: %v", err)
		return false
	}
	log.Printf("[yozakura] the shell's polkit agent is gone; started %s %s", launcher, compositor.FallbackVerb)
	return true
}

// shellLostPolkit is the default qsHooks.shellLost: polkitTakeover with
// the compositor service's last report.
func (d *Daemon) shellLostPolkit() {
	if d.compositor == nil {
		return
	}
	polkitTakeover(d.compositor.PolkitReport(), selfLauncher(), spawnDetached)
}

// selfLauncher is the command that runs this binary now: the packaging
// launcher (it sets the wrapper's environment), else this executable.
func selfLauncher() string {
	if l := paths.Launcher(""); l != "" {
		return l
	}
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	return exe
}

// spawnDetached starts argv in its own session, outliving the daemon
// (which exits right after a crash loop).
func spawnDetached(argv []string) error {
	cmd := proc.Command(context.Background(), argv[0], argv[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if home, err := os.UserHomeDir(); err == nil {
		cmd.Dir = home
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	go func() { _ = cmd.Wait() }() // reaped if the daemon outlives it
	return nil
}
