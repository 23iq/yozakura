// Package displays lists outputs, applies monitor changes live behind a
// confirm-or-revert session, and finds/moves user monitor rules that would
// override the generated compositor config.
//
// IPC (service "displays"):
//
//	list           → []ipc.Output
//	apply          {outputs: []OutputConfig} → {session, revertIn, live}
//	keep           {session} → {ok, saved}: the candidate is saved into
//	               displays.monitors (whoever keeps: shell, CLI, MCP)
//	revert         {session}
//	identify       → {outputs: [{name, index}]} (also as an event)
//	conflicts      → [{file, line, text}]
//	moveConflicts  → {outputs, moved, skipped}
//
// Events: displays.session {session, state, remaining, live} every second
// while pending and on every transition; displays.identify. The revert
// timer runs here, so a crashed shell still gets its displays back.
package displays

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/yozdcli"
	yipc "yozakura/backend/pkg/yozd/ipc"
)

// Yozd is the part of the compositor daemon this service needs.
type Yozd interface {
	Outputs() ([]yipc.Output, error)
	ApplyOutput(yipc.OutputConfig) error
}

type yozdApplier struct{ y Yozd }

func (a yozdApplier) Apply(c yipc.OutputConfig) error { return a.y.ApplyOutput(c) }

// Service is the displays IPC service.
type Service struct {
	yozd                   Yozd
	mgr                    *Manager
	hyprDir, dataDir, home string
	now                    func() time.Time
	tick                   time.Duration
	// exclusive reports exclusive mode: the user's old compositor files are
	// no longer loaded then, so they cannot conflict.
	exclusive func() bool

	// persist saves a kept candidate (displays.monitors); outs are the
	// outputs at apply time (stable ids). nil: nothing is saved.
	persist func(cand []yipc.OutputConfig, outs []yipc.Output) error
	sessMu  sync.Mutex
	sessOut map[string][]yipc.Output // session id → outputs at apply
	saved   map[string]bool          // session id → its keep saved it

	timerMu sync.Mutex
	timerOn bool
	stop    chan struct{}
	closed  sync.Once

	subsMu  sync.Mutex
	subs    []*ipc.Subscriber
	onEvent func(name string, data any) // tests
}

// NewService scans ~/.config/hypr (XDG) and skips the app's data dir.
func NewService(p *paths.Paths) *Service {
	s := newService(yozdcli.New(), paths.HyprDir(), p.DataDir)
	s.home, _ = os.UserHomeDir()
	return s
}

func newService(y Yozd, hyprDir, dataDir string) *Service {
	return &Service{
		yozd: y, mgr: NewManager(yozdApplier{y}),
		hyprDir: hyprDir, dataDir: dataDir,
		now: time.Now, tick: time.Second,
		stop: make(chan struct{}),
	}
}

// HyprDir is the config dir the service scans.
func (s *Service) HyprDir() string { return s.hyprDir }

// SetExclusiveCheck installs the exclusive-mode probe; while it reports true
// the conflict scan finds nothing.
func (s *Service) SetExclusiveCheck(f func() bool) { s.exclusive = f }

// SetPersist installs the saver of kept layouts.
func (s *Service) SetPersist(f func(cand []yipc.OutputConfig, outs []yipc.Output) error) {
	s.persist = f
}

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "displays",
		Methods: map[string]ipc.HandlerFunc{
			"list":          s.list,
			"apply":         s.apply,
			"keep":          s.keep,
			"revert":        s.revert,
			"identify":      s.identify,
			"conflicts":     s.conflicts,
			"moveConflicts": s.moveConflicts,
		},
		Subscribe: s.subscribe,
		// each of these runs the daemon CLI or walks the filesystem
		Async: map[string]bool{
			"list": true, "apply": true, "revert": true, "identify": true,
			"conflicts": true, "moveConflicts": true,
		},
	})
}

// Close stops the timer and reverts a pending session: an unconfirmed
// change must not outlive the backend.
func (s *Service) Close() {
	s.closed.Do(func() { close(s.stop) })
	if cur := s.mgr.Current(); cur != nil && cur.State == StatePending {
		_ = s.mgr.Revert(cur.ID)
	}
}

func (s *Service) list(json.RawMessage) (any, error) {
	out, err := s.yozd.Outputs()
	if out == nil {
		out = []yipc.Output{}
	}
	return out, err
}

type sessionParams struct {
	Session string `json:"session"`
}

func (s *Service) apply(params json.RawMessage) (any, error) {
	var p struct {
		Outputs []yipc.OutputConfig `json:"outputs"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("displays.apply: %w", err)
	}
	select {
	case <-s.stop:
		return nil, fmt.Errorf("displays.apply: shutting down")
	default:
	}
	if len(p.Outputs) == 0 {
		return nil, fmt.Errorf("displays.apply: no outputs")
	}
	for _, c := range p.Outputs {
		if err := c.Validate(); err != nil {
			return nil, fmt.Errorf("displays.apply: %w", err)
		}
	}
	current, err := s.yozd.Outputs()
	if err != nil {
		return nil, fmt.Errorf("displays.apply: snapshot: %w", err)
	}
	sess, err := s.mgr.Start(s.now(), snapshotFor(current, p.Outputs), p.Outputs)
	if sess != nil {
		s.sessMu.Lock()
		// one session at a time: older entries are gone with it
		s.sessOut = map[string][]yipc.Output{sess.ID: current}
		s.sessMu.Unlock()
		s.publishSession(sess)
	}
	if err != nil {
		return nil, fmt.Errorf("displays.apply: %w", err)
	}
	s.ensureTimer()
	return map[string]any{"session": sess.ID, "revertIn": int(RevertAfter.Seconds()), "live": sess.Live}, nil
}

// snapshotFor is the current state of the outputs the candidate touches
// (unknown outputs cannot be restored and are left out).
func snapshotFor(current []yipc.Output, cand []yipc.OutputConfig) []yipc.OutputConfig {
	byName := map[string]yipc.Output{}
	for _, o := range current {
		byName[o.Name] = o
	}
	var snap []yipc.OutputConfig
	for _, c := range cand {
		if o, ok := byName[c.Name]; ok {
			snap = append(snap, configFromOutput(o))
		}
	}
	return snap
}

func configFromOutput(o yipc.Output) yipc.OutputConfig {
	c := yipc.OutputConfig{
		Name: o.Name, Enabled: o.Enabled,
		Width: o.Width, Height: o.Height, Refresh: o.Refresh,
		X: o.X, Y: o.Y, Scale: o.Scale, Transform: o.Transform,
	}
	if o.VRR {
		c.VRR = 1
	}
	return c
}

func (s *Service) keep(params json.RawMessage) (any, error) {
	var p sessionParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("displays.keep: %w", err)
	}
	kept, again, err := s.mgr.Keep(p.Session)
	if err != nil {
		return nil, err
	}
	s.sessMu.Lock()
	defer s.sessMu.Unlock()
	if again {
		return map[string]any{"ok": true, "saved": s.saved[kept.ID]}, nil
	}
	s.publishSession(kept)
	if s.persist == nil {
		return map[string]any{"ok": true, "saved": false}, nil
	}
	if err := s.persist(kept.Candidate, s.sessOut[kept.ID]); err != nil {
		return nil, fmt.Errorf("displays.keep: kept, but saving the layout failed: %w", err)
	}
	s.saved = map[string]bool{kept.ID: true}
	return map[string]any{"ok": true, "saved": true}, nil
}

func (s *Service) revert(params json.RawMessage) (any, error) {
	var p sessionParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("displays.revert: %w", err)
	}
	err := s.mgr.Revert(p.Session)
	if cur := s.mgr.Current(); cur != nil && cur.ID == p.Session && cur.State == StateReverted {
		s.publishSession(cur)
	}
	if err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

// ensureTimer starts the 1 s ticker unless it is already running. It stops
// itself once no session is pending.
func (s *Service) ensureTimer() {
	s.timerMu.Lock()
	defer s.timerMu.Unlock()
	if s.timerOn {
		return
	}
	s.timerOn = true
	go s.runTimer()
}

func (s *Service) runTimer() {
	t := time.NewTicker(s.tick)
	defer t.Stop()
	for {
		select {
		case <-t.C:
		case <-s.stop:
			return
		}
		if exp := s.mgr.Tick(s.now()); exp != nil {
			s.publishSession(exp)
		}
		s.timerMu.Lock()
		cur := s.mgr.Current()
		if cur == nil || cur.State != StatePending || !cur.Live {
			s.timerOn = false
			s.timerMu.Unlock()
			return
		}
		s.timerMu.Unlock()
		s.publishSession(cur)
	}
}

func (s *Service) publishSession(sess *Session) {
	s.publish("displays.session", map[string]any{
		"session":   sess.ID,
		"state":     sess.State,
		"remaining": s.mgr.Remaining(s.now()),
		"live":      sess.Live,
	})
}

type identified struct {
	Name  string `json:"name"`
	Index int    `json:"index"`
}

// identify numbers the enabled outputs left to right, then top to bottom.
func (s *Service) identify(json.RawMessage) (any, error) {
	outs, err := s.yozd.Outputs()
	if err != nil {
		return nil, err
	}
	var on []yipc.Output
	for _, o := range outs {
		if o.Enabled {
			on = append(on, o)
		}
	}
	sort.SliceStable(on, func(i, j int) bool {
		if on[i].X != on[j].X {
			return on[i].X < on[j].X
		}
		return on[i].Y < on[j].Y
	})
	list := make([]identified, len(on))
	for i, o := range on {
		list[i] = identified{Name: o.Name, Index: i + 1}
	}
	res := map[string]any{"outputs": list}
	s.publish("displays.identify", res)
	return res, nil
}

func (s *Service) conflicts(json.RawMessage) (any, error) {
	if s.exclusive != nil && s.exclusive() {
		return []Conflict{}, nil
	}
	return ScanConflicts(s.hyprDir, s.dataDir)
}

func (s *Service) moveConflicts(json.RawMessage) (any, error) {
	return MoveConflicts(s.hyprDir, s.dataDir, s.home)
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs = append(s.subs, sub)
	s.subsMu.Unlock()
	if cur := s.mgr.Current(); cur != nil && cur.State == StatePending {
		sub.Send("displays.session", map[string]any{
			"session": cur.ID, "state": cur.State,
			"remaining": s.mgr.Remaining(s.now()), "live": cur.Live,
		})
	}
	go func() {
		<-sub.StopCh()
		s.subsMu.Lock()
		defer s.subsMu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

func (s *Service) publish(name string, data any) {
	if s.onEvent != nil {
		s.onEvent(name, data)
	}
	s.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.subsMu.Unlock()
	for _, sub := range subs {
		sub.Send(name, data)
	}
}
