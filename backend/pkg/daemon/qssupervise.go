package daemon

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"
	"syscall"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/proc"
)

// qsHooks are the side effects of shell supervision; tests swap them.
type qsHooks struct {
	// start launches the shell and returns its exit channel and pid.
	start func(shellQML string) (<-chan error, int, error)
	// kill SIGKILLs the process group of the shell with this pid.
	kill  func(pid int)
	now   func() time.Time
	after func(time.Duration) <-chan time.Time
	// tick paces the freeze watchdog (nil: no watchdog).
	tick <-chan time.Time
	// pgid resolves a heartbeat's pid to its process group.
	pgid func(pid int) (int, error)
	// alert tells the user the shell will not come back on its own.
	alert func(title, body string)
	// fallbackShell is the previous mod generation's shell.qml.
	fallbackShell func() string
	// sessionGone reports that the compositor is gone (the user logged
	// out); probe also dials its socket, otherwise only the file is
	// checked. nil: the session is assumed alive.
	sessionGone func(probe bool) bool
}

// defaultQSHooks wires the real process handling for qsBin.
func (d *Daemon) defaultQSHooks(qsBin string) qsHooks {
	return qsHooks{
		start: func(shellQML string) (<-chan error, int, error) {
			if err := d.spawnQS(qsBin, shellQML); err != nil {
				return nil, 0, err
			}
			return waitForProcess(d.qsCmd), d.qsCmd.Process.Pid, nil
		},
		kill: func(pid int) {
			// spawnQS starts the shell in its own process group (pgid = pid)
			_ = syscall.Kill(-pid, syscall.SIGKILL)
		},
		now:           time.Now,
		after:         time.After,
		pgid:          syscall.Getpgid,
		alert:         alertUser,
		fallbackShell: func() string { return filepath.Join(paths.FindShellSource(), "shell.qml") },
		sessionGone:   waylandGone,
	}
}

// waylandGone reports whether the Wayland compositor this daemon was
// started for has exited: its socket file is gone or (probe) refuses a
// connection. Without WAYLAND_DISPLAY nothing is known and it says no.
func waylandGone(probe bool) bool {
	sock := os.Getenv("WAYLAND_DISPLAY")
	if sock == "" {
		return false
	}
	if !filepath.IsAbs(sock) {
		rt := os.Getenv("XDG_RUNTIME_DIR")
		if rt == "" {
			return false
		}
		sock = filepath.Join(rt, sock)
	}
	if _, err := os.Stat(sock); err != nil {
		return os.IsNotExist(err)
	}
	if !probe {
		return false
	}
	c, err := net.DialTimeout("unix", sock, time.Second)
	if err != nil {
		return errors.Is(err, syscall.ECONNREFUSED) || errors.Is(err, syscall.ENOENT)
	}
	_ = c.Close()
	return false
}

// sessionEnded is true once the compositor is gone: the shell exits with
// it and must not be restarted, and the daemon must not outlive the
// session (the next login's daemon would find it holding the lock).
func (d *Daemon) sessionEnded(probe bool) bool {
	if d.hooks.sessionGone == nil || !d.hooks.sessionGone(probe) {
		return false
	}
	log.Printf("[yozakura] the Wayland session ended; shutting down")
	d.shutdown()
	return true
}

// startQS starts the shell and arms supervision for it.
func (d *Daemon) startQS(shellQML string) error {
	done, pid, err := d.hooks.start(shellQML)
	if err != nil {
		return err
	}
	d.qsDone = done
	d.qsPid.Store(int64(pid))
	d.shellQML.Store(shellQML)
	d.wd.disarm()
	return nil
}

// qsExited forgets the shell that just exited.
func (d *Daemon) qsExited() {
	d.qsCmd = nil
	d.qsDone = nil
	d.qsPid.Store(0)
	d.wd.disarm()
	if d.paths != nil {
		if p := d.paths.QsPidFile(); p != "" {
			_ = os.Remove(p)
		}
	}
}

// heartbeat is system.heartbeat: the shell's GUI thread is alive. Only the
// supervised shell counts (a dry-run or hand-started qs has another pid).
func (d *Daemon) heartbeat(raw json.RawMessage) (any, error) {
	var p struct {
		PID int `json:"pid"`
	}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &p)
	}
	cur := int(d.qsPid.Load())
	if cur <= 0 || p.PID <= 0 {
		return map[string]any{"ok": false}, nil
	}
	if p.PID != cur {
		// a wrapper may exec qs under another pid inside the group
		if g, err := d.hooks.pgid(p.PID); err != nil || g != cur {
			return map[string]any{"ok": false}, nil
		}
	}
	d.wd.beat(d.hooks.now())
	return map[string]any{"ok": true}, nil
}

// ErrShellCrashLoop is why the daemon exits when the shell crash loops.
var ErrShellCrashLoop = errors.New("the shell keeps crashing; stopped")

// scheduleRestart counts an exit (cause) and returns when to start the
// shell again, or nil once it is crash looping (the user is told then and
// the daemon exits: idling without a shell would keep holding the
// instance lock, and with an unknown or dead session the next login's
// daemon would find it "already running" and show no shell. A shell
// keybind or `reload` starts a fresh daemon, with a fresh guard).
func (d *Daemon) scheduleRestart(cause error) <-chan time.Time {
	delay, giveUp := d.guard.record(d.hooks.now())
	if giveUp {
		log.Printf("[yozakura] qs crashed more than %d times in %v (last: %v); not restarting it, exiting", CrashLoopMax, CrashWindow, cause)
		d.hooks.alert(brand.DisplayName+" shell keeps crashing",
			fmt.Sprintf("Stopped it. Run `%s reload` (or press a shell keybind) to try again; logs: `%s doctor`.", brand.AppID, brand.AppID))
		return nil
	}
	log.Printf("[yozakura] qs exited (%v); restarting in %v", cause, delay)
	return d.hooks.after(delay)
}

// supervise runs the shell until a shutdown request: it restarts a shell
// that exits on its own (backoff, crash-loop guard), kills a frozen one,
// and keeps the mod-activation rollback. It returns nil for a requested
// shutdown or the end of the Wayland session (the shell exits with the
// compositor at logout) and an error when the daemon has to exit because
// of the shell (ErrShellCrashLoop, a failed rollback start).
func (d *Daemon) supervise(sigCh <-chan os.Signal, shellQML string, healthCh <-chan time.Time) error {
	var restartCh <-chan time.Time
	for {
		select {
		case s := <-sigCh:
			log.Printf("[yozakura] received %v, shutting down", s)
			d.shutdown()
			return nil
		case <-d.shutdownCh:
			log.Printf("[yozakura] shutdown requested via IPC")
			d.shutdown()
			return nil
		case <-healthCh:
			if err := d.mods.MarkHealthy(); err != nil {
				log.Printf("[yozakura] mod activation health check: %v", err)
			}
			healthCh = nil
		case <-d.hooks.tick:
			// no shell to exit with the compositor: dial its socket, a
			// crashed compositor leaves the file behind (cheap, and only
			// while a restart is pending)
			if d.qsPid.Load() == 0 && d.sessionEnded(true) {
				return nil
			}
			if pid := int(d.qsPid.Load()); pid > 0 && d.wd.expired(d.hooks.now()) {
				log.Printf("[yozakura] qs sent no heartbeat for %v; killing the frozen shell", WatchdogTimeout)
				d.wd.disarm()
				d.hooks.kill(pid)
			}
		case <-restartCh:
			restartCh = nil
			if d.sessionEnded(true) {
				return nil
			}
			if err := d.startQS(shellQML); err != nil {
				if restartCh = d.scheduleRestart(fmt.Errorf("spawn: %w", err)); restartCh == nil {
					d.shutdown()
					return ErrShellCrashLoop
				}
			}
		case err := <-d.qsDone:
			d.qsExited()
			if d.sessionEnded(true) {
				return nil
			}
			if healthCh != nil {
				healthCh = nil
				recovered, recoverErr := d.mods.RecoverFailedActivation()
				if recoverErr != nil {
					log.Printf("[yozakura] mod activation rollback: %v", recoverErr)
				}
				if recovered {
					shellQML = d.hooks.fallbackShell()
					log.Printf("[yozakura] retrying with previous shell generation")
					if spawnErr := d.startQS(shellQML); spawnErr != nil {
						d.shutdown()
						return fmt.Errorf("spawn rollback shell: %w", spawnErr)
					}
					continue
				}
			}
			if restartCh = d.scheduleRestart(err); restartCh == nil {
				d.shutdown()
				return ErrShellCrashLoop
			}
		}
	}
}

// alertUser shows a notification without the shell (it is the usual
// notification server): notify-send for another server, then Hyprland's
// own overlay. Synchronous (bounded to 3 s per try): the daemon exits
// right after it, which would kill a background sender before it ran.
func alertUser(title, body string) {
	try := func(name string, args ...string) bool {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		return proc.Do(ctx, name, args...) == nil
	}
	if try("notify-send", "-u", "critical", "-a", brand.DisplayName, title, body) {
		return
	}
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "" {
		try("hyprctl", "notify", "3", "30000", "0", title+": "+body)
	}
}
