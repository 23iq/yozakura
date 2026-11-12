package compositor

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/envclean"
	"yozakura/backend/pkg/instancelock"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/yozd/client"
)

// State is the snapshot pushed to subscribers on every event of the daemon's
// System.Subscribe stream (yozd = brand.Daemon). Mirrors the shape the QML service consumed
// before the refactor.
type State struct {
	Windows      []json.RawMessage `json:"windows,omitempty"`
	Workspaces   []json.RawMessage `json:"workspaces,omitempty"`
	Monitors     []json.RawMessage `json:"monitors,omitempty"`
	OverviewOpen *bool             `json:"overview_open,omitempty"`
	// KeyboardLayout is yozd's last keyboard_layout event payload
	// ({"name", "index"?, "names"?}); absent until the first switch.
	KeyboardLayout json.RawMessage `json:"keyboard_layout,omitempty"`
}

const subscribeRetryDelay = 500 * time.Millisecond

// maxSubscribeLine bounds one event line of the subscribe stream (a full
// state dump with every window); a longer line drops the connection, which
// is then re-established.
const maxSubscribeLine = 8 * 1024 * 1024
const socketWaitStep = 100 * time.Millisecond

// socketWaitTimeout is a variable so tests can shorten it.
var socketWaitTimeout = 5 * time.Second

// daemonHeldRecheck is how often the supervisor re-checks a lock held by
// a foreign daemon instance.
const daemonHeldRecheck = 3 * time.Second

// Manager owns the long-running compositor daemon child (yozd daemon) and
// its event stream, and exposes the state to the rest of the compositor
// service. The Manager is started once by the daemon and shut down on daemon
// exit; the child is placed in its own process group so a single SIGKILL
// cleans it up. The child is supervised: it is reaped by its own goroutine
// and restarted if it exits before Close (e.g. killed from outside). The
// event stream is read in-process from the daemon socket and re-established
// whenever it drops.
type Manager struct {
	tomlPath  string
	configDir string
	bin       string // resolved daemon executable (paths.DaemonBinary)

	mu      sync.RWMutex
	state   State
	started bool

	daemonMu  sync.Mutex
	daemonCmd *exec.Cmd
	stopping  bool // set by Close under daemonMu; no restarts after it

	subsMu      sync.Mutex
	subscribers map[chan State]struct{}

	idle *idleHub // idle monitor flips (idle.go)

	stopCh chan struct{}
	// stopCtx is cancelled by Close; it aborts a blocked socket read.
	stopCtx    context.Context
	stopCancel context.CancelFunc
	wg         sync.WaitGroup
}

// NewManager constructs a Manager. nil defaults to the same XDG layout the
// QML side used so the on-disk layout does not change.
func NewManager(p PathResolver) *Manager {
	m := &Manager{
		stopCh:      make(chan struct{}),
		subscribers: make(map[chan State]struct{}),
		idle:        newIdleHub(),
	}
	m.stopCtx, m.stopCancel = context.WithCancel(context.Background())
	if p == nil {
		m.tomlPath = defaultTomlPath()
	} else {
		m.tomlPath = p.DaemonToml()
	}
	m.configDir = filepath.Dir(m.tomlPath)
	m.bin = paths.DaemonBinary()
	return m
}

// Start ensures the daemon config dir exists, then launches `yozd daemon`
// and the goroutine that subscribes to its socket. The child runs in its own
// process group so Close() can SIGKILL the whole group in one shot.
func (m *Manager) Start() error {
	if _, err := exec.LookPath(m.bin); err != nil {
		return fmt.Errorf("%s not found next to the executable or in PATH: %w", brand.Daemon, err)
	}
	if err := os.MkdirAll(m.configDir, 0o755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	m.mu.Lock()
	if m.started {
		m.mu.Unlock()
		return nil
	}
	m.mu.Unlock()

	m.daemonMu.Lock()
	cmd, err := m.startDaemonLocked()
	m.daemonMu.Unlock()
	if err != nil {
		return err
	}

	m.wg.Add(2)
	go m.superviseDaemon(cmd)
	go m.subscribeLoop()

	m.mu.Lock()
	m.started = true
	m.mu.Unlock()
	return nil
}

// startDaemonLocked launches the daemon; the caller holds daemonMu.
func (m *Manager) startDaemonLocked() (*exec.Cmd, error) {
	cmd := exec.CommandContext(context.Background(), m.bin, "-c", m.tomlPath, "daemon")
	cmd.Env = envclean.ChildEnv()
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	// The daemon's own messages (config load and apply errors) go to the
	// backend log, prefixed and bounded (daemonlog.go).
	out := newLineLog(os.Stderr, "[compositor] "+brand.Daemon+": ")
	cmd.Stdout, cmd.Stderr = out, out
	// A child still holding the pipes must not keep Wait (and the
	// restart) waiting after the daemon itself exited.
	cmd.WaitDelay = 2 * time.Second
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("%s daemon: %w", brand.Daemon, err)
	}
	m.daemonCmd = cmd
	return cmd, nil
}

// superviseDaemon reaps the daemon and restarts it whenever it exits
// before Close, with a backoff (restart.go). Without it a daemon killed from
// outside stayed a zombie and every daemon client failed with "connection
// refused" until a full restart.
func (m *Manager) superviseDaemon(cmd *exec.Cmd) {
	defer m.wg.Done()
	var policy restartPolicy
	started := time.Now()
	for {
		// Forget the daemon before reaping it: Close signals daemonCmd
		// under daemonMu, so it only ever sees a process not yet reaped.
		waitExited(cmd.Process.Pid)
		m.daemonMu.Lock()
		if m.daemonCmd == cmd {
			m.daemonCmd = nil
		}
		m.daemonMu.Unlock()
		err := cmd.Wait()

		noComp := exitedNoCompositor(err)
		delay, first := policy.next(time.Since(started), noComp)
		switch {
		case !noComp:
			logf("[compositor] %s daemon exited (%v), restarting in %v\n", brand.Daemon, err, delay)
		case first:
			logf("[compositor] %s found no supported compositor; retrying with a backoff of up to %v (compositor features are off meanwhile)\n", brand.Daemon, noCompositorMax)
		}

		for {
			select {
			case <-m.stopCh:
				return
			case <-time.After(delay):
			}
			// Another daemon owns the instance lock: respawning would only
			// make it refuse again, so keep waiting until it is gone.
			if _, held := instancelock.Held(instancelock.DaemonPath(brand.DaemonSocketPath())); held {
				delay = daemonHeldRecheck
				continue
			}
			m.daemonMu.Lock()
			if m.stopping {
				m.daemonMu.Unlock()
				return
			}
			next, startErr := m.startDaemonLocked()
			m.daemonMu.Unlock()
			if startErr == nil {
				cmd = next
				started = time.Now()
				break
			}
			delay, _ = policy.next(0, false)
			logf("[compositor] %v, retrying in %v\n", startErr, delay)
		}
	}
}

// daemonPID returns the running daemon's pid, or 0.
func (m *Manager) daemonPID() int {
	m.daemonMu.Lock()
	defer m.daemonMu.Unlock()
	if m.daemonCmd == nil || m.daemonCmd.Process == nil {
		return 0
	}
	return m.daemonCmd.Process.Pid
}

// waitForSocket blocks until the daemon socket exists, the timeout elapses
// or the Manager is closed.
func (m *Manager) waitForSocket(path string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if info, err := os.Stat(path); err == nil && info.Mode()&os.ModeSocket != 0 {
			return nil
		}
		select {
		case <-m.stopCh:
			return fmt.Errorf("compositor manager closed")
		case <-time.After(socketWaitStep):
		}
	}
	return fmt.Errorf("%s socket %s did not appear", brand.Daemon, path)
}

// subscribeLoop keeps a System.Subscribe connection to the daemon socket
// open. It waits for the socket before connecting, and reconnects after a
// short delay whenever the stream ends (the daemon being restarted, a
// transient disconnect, an oversized line).
func (m *Manager) subscribeLoop() {
	defer m.wg.Done()
	// a missing socket is logged once per outage, not every socketWaitTimeout
	// (a session without a supported compositor never gets one)
	warned := false
	for {
		select {
		case <-m.stopCh:
			return
		default:
		}

		path := brand.DaemonSocketPath()
		if err := m.waitForSocket(path, socketWaitTimeout); err != nil {
			select {
			case <-m.stopCh:
				return
			default:
			}
			// The daemon may be restarting; keep trying rather than leaving
			// the shell without compositor state for the rest of the session.
			if !warned {
				logf("[compositor] %v, retrying\n", err)
				warned = true
			}
			continue
		}
		warned = false

		_ = client.Subscribe(m.stopCtx, path, maxSubscribeLine, m.handleLine)
		m.idle.streamDown()

		select {
		case <-m.stopCh:
			return
		case <-time.After(subscribeRetryDelay):
		}
	}
}

// readSubscribe feeds every line of r to handleLine (tests drive it with a
// recorded stream).
func (m *Manager) readSubscribe(r io.Reader) {
	_ = client.ReadLines(r, maxSubscribeLine, m.handleLine)
}

// handleLine applies one line of the subscribe stream; lines without a
// state (the subscribe reply, garbage) are ignored. The State.Dump opening
// a stream and idle monitor flips also go to the idle hub (idle.go).
func (m *Manager) handleLine(line []byte) {
	// One decode per line: the state is unmarshalled straight into State
	// (it used to go through a json.RawMessage and a second Unmarshal).
	var payload struct {
		Method   string          `json:"method"`
		Params   json.RawMessage `json:"params"`
		Features []string        `json:"features"`
		State    *State          `json:"state"`
	}
	if err := json.Unmarshal(line, &payload); err != nil {
		return
	}
	switch payload.Method {
	case client.StateDumpMethod:
		m.idle.streamUp(payload.Features)
	case client.IdleMonitorChangedEvent:
		m.idle.change(payload.Params)
	}
	if payload.State == nil {
		return
	}
	m.setState(*payload.State)
	m.broadcast(*payload.State)
}

func (m *Manager) setState(st State) {
	m.mu.Lock()
	m.state = st
	m.mu.Unlock()
}

// State returns the last known snapshot.
func (m *Manager) State() State {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.state
}

func (m *Manager) broadcast(st State) {
	m.subsMu.Lock()
	defer m.subsMu.Unlock()
	for c := range m.subscribers {
		sendLatest(c, st)
	}
}

// sendLatest queues st on c without blocking. A full channel drops its
// oldest queued snapshot, so a slow subscriber always ends on the newest
// state rather than on a stale one. Callers hold subsMu so a concurrent
// cancel cannot close c under the send.
func sendLatest(c chan State, st State) {
	for {
		select {
		case c <- st:
			return
		default:
		}
		select {
		case <-c:
		default:
		}
	}
}

// Subscribe returns a channel that receives every state update and a cancel
// function that removes the subscription. The channel is closed when the
// Manager shuts down.
func (m *Manager) Subscribe() (<-chan State, func()) {
	ch := make(chan State, 16)
	m.subsMu.Lock()
	m.subscribers[ch] = struct{}{}
	m.subsMu.Unlock()
	cancel := func() {
		m.subsMu.Lock()
		if _, ok := m.subscribers[ch]; ok {
			delete(m.subscribers, ch)
			close(ch)
		}
		m.subsMu.Unlock()
	}
	return ch, cancel
}

// Dispatch runs a one-shot daemon command. The returned stdout/stderr is
// captured and forwarded; exit code is reported.
func (m *Manager) Dispatch(args []string) (string, int, error) {
	if len(args) == 0 {
		return "", 0, fmt.Errorf("dispatch: empty args")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, m.bin, args...).CombinedOutput()
	exit := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			exit = ee.ExitCode()
		} else {
			return strings.TrimSpace(string(out)), 0, err
		}
	}
	return strings.TrimSpace(string(out)), exit, nil
}

// Eval runs a Hyprland Lua expression via the daemon's raw-batch wrapper around
// `hyprctl eval <expr>`. Used by the QML shell to push live config changes
// (border colors, rounding, opacities, etc.) without going through the
// TOML regen + watcher + reload cycle, which Hyprland 0.56's Lua config
// does not re-source on a plain `hyprctl reload` for in-progress changes
// and which the daemon's fsnotify watcher currently misses on atomic
// writes to ~/.local/share/yozakura/yozd.toml.
func (m *Manager) Eval(expression string) (string, int, error) {
	expression = strings.TrimSpace(expression)
	if expression == "" {
		return "", 0, fmt.Errorf("eval: empty expression")
	}
	return m.Dispatch([]string{"config", "raw-batch", "eval " + expression})
}

// Close kills the daemon process group and drops the event stream, then
// waits for the supervising goroutines to finish. Safe to call multiple
// times.
func (m *Manager) Close() {
	m.mu.Lock()
	started := m.started
	m.started = false
	m.mu.Unlock()
	if !started {
		return
	}

	// superviseDaemon owns Wait() for the daemon and clears daemonCmd
	// before it reaps it, so under daemonMu a daemon that already exited
	// is never signalled (its pid may belong to another process by now).
	m.daemonMu.Lock()
	m.stopping = true
	killGroup(m.daemonCmd)
	m.daemonMu.Unlock()
	close(m.stopCh)
	m.stopCancel() // closes the subscribe connection

	done := make(chan struct{})
	go func() { m.wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
	}

	m.subsMu.Lock()
	for c := range m.subscribers {
		close(c)
		delete(m.subscribers, c)
	}
	m.subsMu.Unlock()
	m.idle.closeAll()
}

// killGroup SIGKILLs the child's process group; the goroutine that started
// the child reaps it.
func killGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	pgid, err := syscall.Getpgid(cmd.Process.Pid)
	if err != nil || pgid <= 0 {
		pgid = cmd.Process.Pid
	}
	_ = syscall.Kill(-pgid, syscall.SIGKILL)
}
