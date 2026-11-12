package compositor

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"time"

	"yozakura/backend/pkg/yozd/client"
)

// Restart policy of the compositor daemon (superviseDaemon), in the spirit
// of the shell's (daemon.crashGuard): a daemon that exits is started again
// after daemonRestartDelay, doubling with every further exit up to
// daemonRestartMax; one that ran for daemonHealthyRun, or the first exit
// after a "no compositor" streak, starts over at daemonRestartDelay. When it reports that no supported compositor runs
// (client.ExitNoCompositor, e.g. a sway or GNOME session), the first
// noCompositorQuick tries keep the short backoff (a compositor socket that
// is not up yet at login), then it is retried every noCompositorRetry,
// doubling up to noCompositorMax: it used to be restarted every 500 ms for
// the whole session. Variables so tests can shorten them.
var (
	daemonRestartDelay = 500 * time.Millisecond
	daemonRestartMax   = 30 * time.Second
	daemonHealthyRun   = 60 * time.Second
	noCompositorRetry  = 60 * time.Second
	noCompositorMax    = 5 * time.Minute
)

const noCompositorQuick = 3

// logf writes the supervisor's messages to the daemon log; tests swap it.
var logf = func(format string, args ...any) { fmt.Fprintf(os.Stderr, format, args...) }

// restartPolicy is the backoff state of one supervised daemon.
type restartPolicy struct {
	delay  time.Duration // the previous delay; 0 after a healthy run
	noComp int           // consecutive "no supported compositor" exits
}

// next returns how long to wait before restarting a daemon that ran for
// ran and exited (noCompositor: it found no supported compositor). first
// is true for the first exit of a "no compositor" streak, the only one
// worth logging.
func (p *restartPolicy) next(ran time.Duration, noCompositor bool) (delay time.Duration, first bool) {
	// a healthy run, or a start that ended a "no compositor" streak (a
	// compositor came up), starts over at daemonRestartDelay
	if ran >= daemonHealthyRun || (!noCompositor && p.noComp > 0) {
		p.delay = 0
	}
	if noCompositor {
		p.noComp++
	} else {
		p.noComp = 0
	}
	delay = daemonRestartDelay
	if p.delay > 0 {
		delay = 2 * p.delay
	}
	limit := daemonRestartMax
	if p.noComp >= noCompositorQuick {
		delay = max(delay, noCompositorRetry)
		limit = noCompositorMax
	}
	delay = min(delay, limit)
	p.delay = delay
	return delay, p.noComp == 1
}

// exitedNoCompositor reports a daemon exit status of client.ExitNoCompositor.
func exitedNoCompositor(err error) bool {
	var ee *exec.ExitError
	return errors.As(err, &ee) && ee.ExitCode() == client.ExitNoCompositor
}
