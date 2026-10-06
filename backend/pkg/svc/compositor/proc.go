package compositor

import (
	"bufio"
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
	"yozakura/backend/pkg/paths"
)

// State is the snapshot pushed to subscribers on every `yozd subscribe`
// event (yozd = brand.Daemon). Mirrors the shape the QML service consumed
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
const socketWaitStep = 100 * time.Millisecond
const socketWaitTimeout = 5 * time.Second

// daemonRestartDelay throttles restarts of a compositor daemon that exited
// while the Manager was still running.
const daemonRestartDelay = 500 * time.Millisecond

// Manager owns the long-running daemon children (yozd daemon, yozd subscribe)
// and exposes their state to the rest of the compositor service. The Manager
// is started once by the daemon and shut down on daemon exit; child processes
// are placed in their own process group so a single SIGKILL cleans them up.
// Both children are supervised: each is reaped by its own goroutine and
// restarted if it exits before Close (e.g. killed from outside).
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
	subCmdMu  sync.Mutex
	subCmd    *exec.Cmd

	subsMu      sync.Mutex
	subscribers map[chan State]struct{}

	stopCh chan struct{}
	wg     sync.WaitGroup
}

// NewManager constructs a Manager. nil defaults to the same XDG layout the
// QML side used so the on-disk layout does not change.
func NewManager(p PathResolver) *Manager {
	m := &Manager{
		stopCh:      make(chan struct{}),
		subscribers: make(map[chan State]struct{}),
	}
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
// followed by `yozd subscribe`. Both children run in their own process group
// so Close() can SIGKILL the whole group in one shot.
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
	cmd := exec.Command(m.bin, "-c", m.tomlPath, "daemon")
	cmd.Env = envclean.ChildEnv()
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("%s daemon: %w", brand.Daemon, err)
	}
	m.daemonCmd = cmd
	return cmd, nil
}

// superviseDaemon reaps the daemon and restarts it whenever it exits
// before Close. Without it a daemon killed from outside stayed a zombie and
// every daemon client failed with "connection refused" until a full restart.
func (m *Manager) superviseDaemon(cmd *exec.Cmd) {
	defer m.wg.Done()
	for {
		err := cmd.Wait()

		m.daemonMu.Lock()
		if m.daemonCmd == cmd {
			m.daemonCmd = nil
		}
		m.daemonMu.Unlock()

		for {
			select {
			case <-m.stopCh:
				return
			case <-time.After(daemonRestartDelay):
			}
			m.daemonMu.Lock()
			if m.stopping {
				m.daemonMu.Unlock()
				return
			}
			fmt.Fprintf(os.Stderr, "[compositor] %s daemon exited (%v), restarting\n", brand.Daemon, err)
			next, startErr := m.startDaemonLocked()
			m.daemonMu.Unlock()
			if startErr == nil {
				cmd = next
				break
			}
			err = startErr
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

// subscribeLoop keeps a `yozd subscribe` process alive. It waits for the
// daemon socket before launching, and re-launches on premature exit (e.g.
// the daemon being restarted, a transient disconnect).
func (m *Manager) subscribeLoop() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopCh:
			return
		default:
		}

		if err := m.waitForSocket(brand.DaemonSocketPath(), socketWaitTimeout); err != nil {
			select {
			case <-m.stopCh:
				return
			default:
			}
			// The daemon may be restarting; keep trying rather than leaving
			// the shell without compositor state for the rest of the session.
			fmt.Fprintf(os.Stderr, "[compositor] %v, retrying\n", err)
			continue
		}

		cmd := exec.Command(m.bin, "subscribe")
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			time.Sleep(subscribeRetryDelay)
			continue
		}
		cmd.Stderr = io.Discard
		if err := cmd.Start(); err != nil {
			time.Sleep(subscribeRetryDelay)
			continue
		}

		m.subCmdMu.Lock()
		m.subCmd = cmd
		m.subCmdMu.Unlock()
		select {
		case <-m.stopCh: // Close ran between our stop check and Start
			killGroup(cmd)
		default:
		}

		m.readSubscribe(stdout)

		m.subCmdMu.Lock()
		m.subCmd = nil
		m.subCmdMu.Unlock()

		_ = cmd.Wait()

		select {
		case <-m.stopCh:
			return
		case <-time.After(subscribeRetryDelay):
		}
	}
}

func (m *Manager) readSubscribe(r io.Reader) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	for sc.Scan() {
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		var payload struct {
			State json.RawMessage `json:"state"`
		}
		if err := json.Unmarshal(line, &payload); err != nil {
			continue
		}
		if len(payload.State) == 0 {
			continue
		}
		var st State
		if err := json.Unmarshal(payload.State, &st); err != nil {
			continue
		}
		m.setState(st)
		m.broadcast(st)
	}
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
	subs := make([]chan State, 0, len(m.subscribers))
	for c := range m.subscribers {
		subs = append(subs, c)
	}
	m.subsMu.Unlock()
	for _, c := range subs {
		select {
		case c <- st:
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
	cmd := exec.Command(m.bin, args...)
	out, err := cmd.CombinedOutput()
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

// Close kills the daemon process groups, then waits for the supervising
// goroutines to reap them. Safe to call multiple times.
func (m *Manager) Close() {
	m.mu.Lock()
	started := m.started
	m.started = false
	m.mu.Unlock()
	if !started {
		return
	}

	m.daemonMu.Lock()
	m.stopping = true
	daemonCmd := m.daemonCmd
	m.daemonMu.Unlock()
	close(m.stopCh)

	m.subCmdMu.Lock()
	sub := m.subCmd
	m.subCmd = nil
	m.subCmdMu.Unlock()

	// subscribeLoop and superviseDaemon own Wait() for their children.
	killGroup(sub)
	killGroup(daemonCmd)

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
