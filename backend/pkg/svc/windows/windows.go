// Package windows runs the big, rarely opened windows of the shell (the
// Settings window, the setup wizard) as their own Quickshell processes when
// performance.separateWindows is on: nothing of them is loaded until they
// are opened, and closing one gives all of its memory back.
//
// The main shell asks for a window with windows.open (kind, page, screen,
// workspace); the first open starts `qs -p <shell dir>/<entry file>` with
// <PREFIX>ROLE=<kind> (modules/globals/ProcessRole.qml) and the target in
// <PREFIX>WINDOW_*, a later one asks the running process to raise itself
// and show the page (windows.command). One process per kind. A raise
// asked while the window is still starting (not listening yet) is kept,
// the last one per kind, and handed over in the answer to its
// windows.ready; a close then stops the process (it has shown nothing). A closed window reports windows.hiding until its process
// quits; an open meanwhile raises it again. The window quits when it
// closes; the service reaps it, tells every subscriber (windows.state) and
// calls OnExit (the preview relay discards the staging once no window is
// left). A crash of a window never touches the main shell: the window runs
// in its own process group and is not restarted. Close (daemon shutdown,
// reload, quit) stops every window: SIGTERM, then SIGKILL of every group
// still there after StopWait.
//
// windows.relay carries small messages between the processes (to "shell"
// or a kind): the window asks the main shell to act on what only it owns
// (the wallpaper manager), and the main shell tells a window what only it
// sees.
package windows

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/ipc"
	procutil "yozakura/backend/pkg/proc"
)

// Window kinds.
const (
	KindSettings   = "settings"
	KindOnboarding = "onboarding"
)

// entryFiles are the root QML files of each kind, next to shell.qml.
var entryFiles = map[string]string{
	KindSettings:   "settings-window.qml",
	KindOnboarding: "onboarding-window.qml",
}

// EntryFile is the root QML file name of kind ("" for an unknown kind).
func EntryFile(kind string) string { return entryFiles[kind] }

// ShellEntryFiles are the root QML files the daemon runs Quickshell on: the
// shell and every separate window (the orphan sweep recognises them).
func ShellEntryFiles() []string {
	return []string{"shell.qml", entryFiles[KindSettings], entryFiles[KindOnboarding]}
}

// Window states (windows.state).
const (
	StateClosed   = "closed"
	StateStarting = "starting" // process started, window not shown yet
	StateOpen     = "open"     // the window reported it is shown (windows.ready)
	StateHiding   = "hiding"   // closed by the user, the process quits soon (windows.hiding)
)

// Env names (with brand.EnvPrefix) the window process reads.
const (
	EnvRole      = "ROLE"
	EnvPage      = "WINDOW_PAGE"
	EnvScreen    = "WINDOW_SCREEN"
	EnvWorkspace = "WINDOW_WORKSPACE"
)

// StopWait is how long Close (and a close of a window still starting)
// waits after SIGTERM before SIGKILL.
var StopWait = 1500 * time.Millisecond

// Process is a started window process.
type Process interface {
	Pid() int
	// Wait blocks until the process exited.
	Wait() error
	// Signal signals the process group.
	Signal(sig syscall.Signal) error
}

// StartFunc starts argv with env (the daemon's Quickshell spawner).
type StartFunc func(argv, env []string) (Process, error)

// Options configure the service.
type Options struct {
	// QS is the Quickshell binary (the same one the shell runs).
	QS func() string
	// ShellDir is the directory of the shell.qml the main shell runs now
	// (a mods generation or the base source); BaseDir the unmodified base
	// source, tried when ShellDir lacks the entry file.
	ShellDir, BaseDir func() string
	// Env is the environment of the shell's Quickshell (without the role).
	Env func() []string
	// Start starts a process; nil uses StartGroup.
	Start StartFunc
	// OnExit runs after a window process of kind exited (any reason).
	OnExit func(kind string)
}

// Request is windows.open: which window, and where.
type Request struct {
	Kind      string `json:"kind"`
	Page      string `json:"page,omitempty"`
	Screen    string `json:"screen,omitempty"`
	Workspace int    `json:"workspace,omitempty"`
}

// Command is the windows.command event: a running window is asked to
// raise itself (and show Page on Screen) or to close.
type Command struct {
	Kind      string `json:"kind"`
	Action    string `json:"action"` // "raise" | "close"
	Page      string `json:"page,omitempty"`
	Screen    string `json:"screen,omitempty"`
	Workspace int    `json:"workspace,omitempty"`
}

// Status is one kind's state (windows.state event, windows.status).
// Shutdown marks a window stopped by the daemon's shutdown (Close): the
// main shell must not take it for a failed start and open the window
// in-process.
type Status struct {
	Kind     string `json:"kind"`
	State    string `json:"state"`
	Pid      int    `json:"pid,omitempty"`
	Error    string `json:"error,omitempty"`
	Shutdown bool   `json:"shutdown,omitempty"`
}

// Relay is a windows.relay message.
type Relay struct {
	To    string          `json:"to"` // "shell" or a kind
	Topic string          `json:"topic"`
	Data  json.RawMessage `json:"data,omitempty"`
}

type instance struct {
	proc  Process
	state string
	done  chan struct{}
	// The last command asked while the window was starting (not listening
	// yet); windows.ready hands it over.
	pending *Command
	// Closed while it was still starting: being stopped (never shown).
	stopping bool
}

// Service is the "windows" IPC service.
type Service struct {
	opts Options

	mu      sync.Mutex
	running map[string]*instance
	subs    map[*ipc.Subscriber]struct{}
	closed  bool
}

// NewService returns the service; nothing runs until windows.open.
func NewService(opts Options) *Service {
	if opts.Start == nil {
		opts.Start = StartGroup
	}
	return &Service{opts: opts, running: map[string]*instance{}, subs: map[*ipc.Subscriber]struct{}{}}
}

// Register exposes windows.open/close/ready/status/relay and the stream.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "windows",
		Methods: map[string]ipc.HandlerFunc{
			"open":   s.handleOpen,
			"close":  s.handleClose,
			"ready":  s.handleReady,
			"hiding": s.handleHiding,
			"status": func(json.RawMessage) (any, error) { return s.Statuses(), nil },
			"relay":  s.handleRelay,
		},
		Subscribe: s.subscribe,
	})
}

func decode[T any](raw json.RawMessage) (T, error) {
	var v T
	if len(raw) == 0 {
		return v, nil
	}
	err := json.Unmarshal(raw, &v)
	return v, err
}

func (s *Service) handleOpen(raw json.RawMessage) (any, error) {
	req, err := decode[Request](raw)
	if err != nil {
		return nil, err
	}
	res, err := s.Open(req)
	if err != nil {
		return nil, err
	}
	return map[string]any{"result": res}, nil
}

func (s *Service) handleClose(raw json.RawMessage) (any, error) {
	req, err := decode[Request](raw)
	if err != nil {
		return nil, err
	}
	res, err := s.RequestClose(req.Kind)
	if err != nil {
		return nil, err
	}
	return map[string]any{"result": res}, nil
}

func (s *Service) handleReady(raw json.RawMessage) (any, error) {
	req, err := decode[Request](raw)
	if err != nil {
		return nil, err
	}
	ok, cmd := s.Ready(req.Kind)
	out := map[string]any{"ok": ok}
	if cmd != nil {
		out["command"] = cmd
	}
	return out, nil
}

func (s *Service) handleHiding(raw json.RawMessage) (any, error) {
	req, err := decode[Request](raw)
	if err != nil {
		return nil, err
	}
	return map[string]any{"ok": s.Hiding(req.Kind)}, nil
}

func (s *Service) handleRelay(raw json.RawMessage) (any, error) {
	r, err := decode[Relay](raw)
	if err != nil {
		return nil, err
	}
	if r.To == "" || r.Topic == "" {
		return nil, errors.New("windows.relay: missing to or topic")
	}
	if r.To != "shell" && entryFiles[r.To] == "" {
		return nil, fmt.Errorf("windows.relay: unknown recipient %q", r.To)
	}
	s.broadcast("windows.relay", r)
	return map[string]any{"ok": true}, nil
}

func validKind(kind string) error {
	if entryFiles[kind] == "" {
		return fmt.Errorf("windows: unknown window %q", kind)
	}
	return nil
}

// Open starts the window of req.Kind, or asks the running one to raise
// itself. It returns "started" or "raised".
func (s *Service) Open(req Request) (string, error) {
	if err := validKind(req.Kind); err != nil {
		return "", err
	}
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return "", errors.New("windows: shutting down")
	}
	if inst, ok := s.running[req.Kind]; ok {
		if !inst.stopping {
			s.mu.Unlock()
			s.command(Command{Kind: req.Kind, Action: "raise", Page: req.Page, Screen: req.Screen, Workspace: req.Workspace})
			return "raised", nil
		}
		// closed while starting and being stopped: the open wins, a new
		// process replaces it (its exit is not reported as this kind's)
		delete(s.running, req.Kind)
	}
	qml, err := s.EntryPath(req.Kind)
	if err != nil {
		s.mu.Unlock()
		return "", err
	}
	proc, err := s.opts.Start([]string{s.qs(), "-p", qml}, s.env(req))
	if err != nil {
		s.mu.Unlock()
		return "", fmt.Errorf("windows: start %s: %w", req.Kind, err)
	}
	inst := &instance{proc: proc, state: StateStarting, done: make(chan struct{})}
	s.running[req.Kind] = inst
	s.mu.Unlock()
	log.Printf("[windows] %s started (pid %d, %s)", req.Kind, proc.Pid(), qml)
	s.broadcast("windows.state", Status{Kind: req.Kind, State: StateStarting, Pid: proc.Pid()})
	go s.reap(req.Kind, inst)
	return "started", nil
}

// reap waits for a window process and forgets it.
func (s *Service) reap(kind string, inst *instance) {
	err := inst.proc.Wait()
	s.mu.Lock()
	current := s.running[kind] == inst
	if current {
		delete(s.running, kind)
	}
	shutdown := s.closed
	s.mu.Unlock()
	close(inst.done)
	st := Status{Kind: kind, State: StateClosed, Shutdown: shutdown}
	if err != nil {
		st.Error = err.Error()
		log.Printf("[windows] %s exited: %v", kind, err)
	}
	// replaced by a new process (opened again while being stopped): that
	// one's state is the kind's
	if current {
		s.broadcast("windows.state", st)
	}
	if s.opts.OnExit != nil {
		s.opts.OnExit(kind)
	}
}

// RequestClose asks the running window of kind to close (it may keep
// itself open to ask about unsaved changes). A window still starting has
// shown nothing and staged nothing: it is stopped instead (SIGTERM, then
// SIGKILL after StopWait), so it never maps only to close itself at
// windows.ready (e.g. over the in-process window the main shell fell back
// to). "closing" or "closed".
func (s *Service) RequestClose(kind string) (string, error) {
	if err := validKind(kind); err != nil {
		return "", err
	}
	s.mu.Lock()
	if inst, ok := s.running[kind]; ok && inst.state == StateStarting {
		if !inst.stopping {
			inst.stopping = true
			inst.pending = nil
			log.Printf("[windows] %s closed while starting: stopping pid %d", kind, inst.proc.Pid())
			go stop(inst, StopWait)
		}
		s.mu.Unlock()
		return "closing", nil
	}
	s.mu.Unlock()
	if !s.command(Command{Kind: kind, Action: "close"}) {
		return StateClosed, nil
	}
	return "closing", nil
}

// stop ends a window process: SIGTERM, then SIGKILL of its group if it is
// still there after wait.
func stop(inst *instance, wait time.Duration) {
	_ = inst.proc.Signal(syscall.SIGTERM)
	t := time.NewTimer(wait)
	defer t.Stop()
	select {
	case <-inst.done:
	case <-t.C:
		_ = inst.proc.Signal(syscall.SIGKILL)
	}
}

// command sends cmd to the running window of its kind; a window still
// starting does not listen yet, so the command (a raise: a close stops
// it, RequestClose) waits for its windows.ready, the last one wins. False
// when no window of that kind runs.
func (s *Service) command(cmd Command) bool {
	s.mu.Lock()
	inst, ok := s.running[cmd.Kind]
	if ok && inst.state == StateStarting {
		c := cmd
		inst.pending = &c
		s.mu.Unlock()
		return true
	}
	s.mu.Unlock()
	if ok {
		s.broadcast("windows.command", cmd)
	}
	return ok
}

// Ready records that the window of kind is shown and hands over the
// command asked while it started (nil when none).
func (s *Service) Ready(kind string) (bool, *Command) {
	s.mu.Lock()
	inst, ok := s.running[kind]
	var cmd *Command
	if ok && inst.stopping {
		// shown just as it was being stopped: it closes itself if the
		// signal has not ended it yet; nothing to report
		s.mu.Unlock()
		return true, &Command{Kind: kind, Action: "close"}
	}
	if ok {
		inst.state = StateOpen
		cmd, inst.pending = inst.pending, nil
	}
	s.mu.Unlock()
	if ok {
		s.broadcast("windows.state", Status{Kind: kind, State: StateOpen, Pid: inst.proc.Pid()})
	}
	return ok, cmd
}

// Hiding records that the window of kind was closed and its process is
// about to quit; a raise (windows.open) shows it again.
func (s *Service) Hiding(kind string) bool {
	s.mu.Lock()
	inst, ok := s.running[kind]
	if ok {
		inst.state = StateHiding
	}
	s.mu.Unlock()
	if ok {
		s.broadcast("windows.state", Status{Kind: kind, State: StateHiding, Pid: inst.proc.Pid()})
	}
	return ok
}

// AnyRunning reports whether a window process of any kind runs (one that
// exited is no longer counted when OnExit runs).
func (s *Service) AnyRunning() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.running) > 0
}

// Statuses is the state of every kind.
func (s *Service) Statuses() []Status {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Status, 0, len(entryFiles))
	for _, kind := range []string{KindSettings, KindOnboarding} {
		st := Status{Kind: kind, State: StateClosed}
		if inst, ok := s.running[kind]; ok {
			st.State, st.Pid = inst.state, inst.proc.Pid()
		}
		out = append(out, st)
	}
	return out
}

// Close stops every window (daemon shutdown): SIGTERM to each group, then
// SIGKILL of every group still there after StopWait. It returns after at
// most twice StopWait, even if a process does not die (it is logged).
// No window starts afterwards.
func (s *Service) Close() {
	s.mu.Lock()
	s.closed = true
	insts := make([]*instance, 0, len(s.running))
	for _, inst := range s.running {
		insts = append(insts, inst)
	}
	s.mu.Unlock()
	for _, inst := range insts {
		_ = inst.proc.Signal(syscall.SIGTERM)
	}
	left := waitExited(insts, StopWait)
	for _, inst := range left {
		_ = inst.proc.Signal(syscall.SIGKILL)
	}
	for _, inst := range waitExited(left, StopWait) {
		log.Printf("[windows] pid %d still running after SIGKILL", inst.proc.Pid())
	}
}

// waitExited waits up to d, in total, for every instance to exit and
// returns the ones still running.
func waitExited(insts []*instance, d time.Duration) []*instance {
	if len(insts) == 0 {
		return nil
	}
	expired := make(chan struct{})
	t := time.AfterFunc(d, func() { close(expired) })
	defer t.Stop()
	var left []*instance
	for _, inst := range insts {
		select {
		case <-inst.done:
		case <-expired:
			select {
			case <-inst.done:
			default:
				left = append(left, inst)
			}
		}
	}
	return left
}

// EntryPath resolves the root QML file of kind: next to the shell the
// daemon runs (a mods generation carries the whole tree), else in the base
// source. Never the executable's directory: on NixOS the shell lives in
// the store path the launcher exports.
func (s *Service) EntryPath(kind string) (string, error) {
	name := entryFiles[kind]
	var dirs []string
	for _, f := range []func() string{s.opts.ShellDir, s.opts.BaseDir} {
		if f != nil {
			if d := f(); d != "" {
				dirs = append(dirs, d)
			}
		}
	}
	for _, d := range dirs {
		p := filepath.Join(d, name)
		if info, err := os.Stat(p); err == nil && info.Mode().IsRegular() {
			return p, nil
		}
	}
	return "", fmt.Errorf("windows: %s not found in %s", name, strings.Join(dirs, ", "))
}

func (s *Service) qs() string {
	if s.opts.QS != nil {
		if q := s.opts.QS(); q != "" {
			return q
		}
	}
	return "qs"
}

// env is the shell's environment with the role and target of req; any
// inherited role, target or dry-run variable is replaced or dropped.
func (s *Service) env(req Request) []string {
	var base []string
	if s.opts.Env != nil {
		base = s.opts.Env()
	} else {
		base = os.Environ()
	}
	drop := map[string]bool{}
	for _, k := range []string{EnvRole, EnvPage, EnvScreen, EnvWorkspace, "DRYRUN", "DRYRUN_DIR", "DRYRUN_FAIL"} {
		drop[brand.EnvPrefix+k] = true
	}
	out := make([]string, 0, len(base)+4)
	for _, kv := range base {
		k, _, _ := strings.Cut(kv, "=")
		if !drop[k] {
			out = append(out, kv)
		}
	}
	return append(out,
		brand.EnvPrefix+EnvRole+"="+req.Kind,
		brand.EnvPrefix+EnvPage+"="+req.Page,
		brand.EnvPrefix+EnvScreen+"="+req.Screen,
		brand.EnvPrefix+EnvWorkspace+"="+strconv.Itoa(req.Workspace))
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	s.mu.Unlock()
	for _, st := range s.Statuses() {
		sub.Send("windows.state", st)
	}
	<-sub.StopCh()
	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
}

func (s *Service) broadcast(event string, data any) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for sub := range s.subs {
		sub.Send(event, data)
	}
}

// groupProc is a process started in its own group (pgid = pid).
type groupProc struct{ cmd *exec.Cmd }

func (g groupProc) Pid() int    { return g.cmd.Process.Pid }
func (g groupProc) Wait() error { return g.cmd.Wait() }
func (g groupProc) Signal(sig syscall.Signal) error {
	return syscall.Kill(-g.cmd.Process.Pid, sig)
}

// StartGroup starts argv in its own process group, output to the daemon's,
// tied to the daemon (it gets SIGTERM if the daemon dies).
func StartGroup(argv, env []string) (Process, error) {
	cmd := exec.CommandContext(context.Background(), argv[0], argv[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	if err := procutil.StartTied(cmd); err != nil {
		return nil, err
	}
	return groupProc{cmd: cmd}, nil
}
