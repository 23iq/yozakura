package transfers

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
)

const (
	// Finished/failed items stay this long so the shell can show them.
	lingerFinished = 3 * time.Second
	// Updates are coalesced to at most one broadcast per interval.
	broadcastEvery = 500 * time.Millisecond
)

type running struct {
	cancel context.CancelFunc
	src    Source
}

// Service is the "transfers" IPC service.
type Service struct {
	mu       sync.Mutex
	opts     Options
	enabled  map[string]bool
	running  map[string]*running
	items    map[string][]Transfer // per source
	finished map[string]time.Time  // id -> first seen done/failed
	dirty    bool
	last     []Transfer
	now      func() time.Time
	subs     map[*ipc.Subscriber]struct{}
	tickerOn bool
}

// NewService returns an idle service; nothing runs until configure.
func NewService() *Service {
	return &Service{
		enabled:  map[string]bool{},
		running:  map[string]*running{},
		items:    map[string][]Transfer{},
		finished: map[string]time.Time{},
		now:      time.Now,
		subs:     map[*ipc.Subscriber]struct{}{},
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "transfers",
		Methods: map[string]ipc.HandlerFunc{
			"configure": s.configure,
			"action":    s.action,
			"status":    s.status,
		},
		Subscribe: s.subscribe,
	})
}

type configureParams struct {
	Sources map[string]bool `json:"sources"`
	Options Options         `json:"options"`
}

func (s *Service) configure(params json.RawMessage) (any, error) {
	var p configureParams
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	s.Configure(p.Sources, p.Options)
	return map[string]any{"sources": SourceNames()}, nil
}

// Configure starts enabled sources and stops the others. Changed options
// restart the running sources.
func (s *Service) Configure(sources map[string]bool, opts Options) {
	s.mu.Lock()
	restart := !reflect.DeepEqual(opts, s.opts)
	s.opts = opts
	for name := range s.running {
		if !sources[name] || restart {
			s.stopLocked(name)
		}
	}
	s.enabled = map[string]bool{}
	for name, on := range sources {
		if !on || factory(name) == nil {
			continue
		}
		s.enabled[name] = true
		if s.running[name] == nil {
			s.startLocked(name)
		}
	}
	s.markDirtyLocked()
	s.mu.Unlock()
}

func (s *Service) startLocked(name string) {
	ctx, cancel := context.WithCancel(context.Background())
	src := factory(name)()
	s.running[name] = &running{cancel: cancel, src: src}
	env := &Env{Options: s.opts, update: func(items []Transfer) { s.setItems(ctx, name, items) }}
	go src.Run(ctx, env)
}

func (s *Service) stopLocked(name string) {
	if r := s.running[name]; r != nil {
		r.cancel()
	}
	delete(s.running, name)
	delete(s.items, name)
}

// Stop cancels every source (daemon shutdown, tests).
func (s *Service) Stop() {
	s.mu.Lock()
	for name := range s.running {
		s.stopLocked(name)
	}
	s.mu.Unlock()
}

func (s *Service) setItems(ctx context.Context, source string, items []Transfer) {
	if ctx.Err() != nil {
		return // stale update from a stopped source
	}
	out := make([]Transfer, 0, len(items))
	for _, it := range items {
		if it.Key == "" {
			continue
		}
		it.Source = source
		it.ID = source + ":" + it.Key
		if it.State == "" {
			it.State = StateRunning
		}
		if it.Kind == "" {
			it.Kind = KindDownload
		}
		if it.Actions == nil {
			it.Actions = []string{}
		}
		out = append(out, it)
	}
	s.mu.Lock()
	s.items[source] = out
	s.markDirtyLocked()
	s.mu.Unlock()
}

func (s *Service) markDirtyLocked() {
	s.dirty = true
	if !s.tickerOn {
		s.tickerOn = true
		go s.pump()
	}
}

// pump coalesces updates; it exits when nothing changed for a while and no
// finished item is still lingering.
func (s *Service) pump() {
	idle := 0
	t := time.NewTicker(broadcastEvery)
	defer t.Stop()
	for range t.C {
		s.mu.Lock()
		list, lingering := s.snapshotLocked()
		changed := s.dirty || lingering
		s.dirty = false
		if changed && !equalTransfers(list, s.last) {
			s.last = list
			s.broadcastLocked(list)
			idle = 0
		} else {
			idle++
		}
		if idle > 4 && !lingering && !s.dirty {
			s.tickerOn = false
			s.mu.Unlock()
			return
		}
		s.mu.Unlock()
	}
}

// snapshotLocked merges every source, drops finished items after the linger
// time and reports whether some finished item is still lingering.
func (s *Service) snapshotLocked() ([]Transfer, bool) {
	now := s.now()
	seen := map[string]bool{}
	lingering := false
	var list []Transfer
	for name, items := range s.items {
		if !s.enabled[name] {
			continue
		}
		for _, it := range items {
			seen[it.ID] = true
			if it.State == StateDone || it.State == StateFailed {
				first, ok := s.finished[it.ID]
				if !ok {
					first = now
					s.finished[it.ID] = now
				}
				if now.Sub(first) > lingerFinished {
					continue
				}
				lingering = true
			} else {
				delete(s.finished, it.ID)
			}
			list = append(list, it)
		}
	}
	for id := range s.finished {
		if !seen[id] {
			delete(s.finished, id)
		}
	}
	sort.Slice(list, func(i, j int) bool {
		if list[i].StartedAt != list[j].StartedAt {
			return list[i].StartedAt < list[j].StartedAt
		}
		return list[i].ID < list[j].ID
	})
	if list == nil {
		list = []Transfer{}
	}
	return list, lingering
}

func equalTransfers(a, b []Transfer) bool {
	if len(a) != len(b) {
		return false
	}
	return reflect.DeepEqual(a, b)
}

func (s *Service) broadcastLocked(list []Transfer) {
	payload := map[string]any{"items": list}
	for sub := range s.subs {
		sub.Send("transfers.state", payload)
	}
}

func (s *Service) status(json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	list, _ := s.snapshotLocked()
	enabled := []string{}
	for k := range s.enabled {
		enabled = append(enabled, k)
	}
	sort.Strings(enabled)
	return map[string]any{"items": list, "enabled": enabled, "sources": SourceNames()}, nil
}

type actionParams struct {
	ID     string `json:"id"`
	Action string `json:"action"`
}

func (s *Service) action(params json.RawMessage) (any, error) {
	var p actionParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	source, key, ok := strings.Cut(p.ID, ":")
	if !ok {
		return nil, fmt.Errorf("bad transfer id %q", p.ID)
	}
	s.mu.Lock()
	r := s.running[source]
	s.mu.Unlock()
	if r == nil {
		return nil, fmt.Errorf("source %q is not running", source)
	}
	actor, ok := r.src.(Actor)
	if !ok {
		return nil, fmt.Errorf("source %q has no actions", source)
	}
	return map[string]any{"ok": true}, actor.Action(key, p.Action)
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	list, _ := s.snapshotLocked()
	s.mu.Unlock()
	sub.Send("transfers.state", map[string]any{"items": list})
	<-sub.StopCh()
	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
}
