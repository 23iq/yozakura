package routines

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
)

// runCap bounds one run (delays are capped at MaxTotalMs).
const runCap = MaxTotalMs + 5*time.Minute

// Service is the `routines` IPC service. The file is re-read on every call
// so hand edits apply without a restart.
type Service struct {
	path   string
	exec   Executor
	notify func(summary, body string)

	mu     sync.Mutex // serialises writers
	subsMu sync.Mutex
	subs   map[*ipc.Subscriber]struct{}
}

// Options configure NewService.
type Options struct {
	Path string // routines.json
	Exec Executor
	// Notify reports a failed run that nobody watches (nil: silent).
	Notify func(summary, body string)
}

// NewService builds the service; the executor's Lookup is filled in.
func NewService(o Options) *Service {
	s := &Service{path: o.Path, exec: o.Exec, notify: o.Notify, subs: map[*ipc.Subscriber]struct{}{}}
	if s.exec.Lookup == nil {
		s.exec.Lookup = s.lookup
	}
	return s
}

// Register wires the IPC methods.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{Name: "routines", Methods: s.methods(), Subscribe: s.subscribe})
}

func (s *Service) methods() map[string]ipc.HandlerFunc {
	return map[string]ipc.HandlerFunc{
		"list":   s.list,
		"get":    s.get,
		"save":   s.save,
		"delete": s.remove,
		"run":    s.run,
	}
}

// List returns the saved routines.
func (s *Service) List() ([]Routine, error) { return Load(s.path) }

func (s *Service) lookup(ref string) (Routine, bool) {
	list, err := Load(s.path)
	if err != nil {
		return Routine{}, false
	}
	if i := Find(list, ref); i >= 0 {
		return list[i], true
	}
	return Routine{}, false
}

func (s *Service) list(_ json.RawMessage) (any, error) {
	list, err := Load(s.path)
	if err != nil {
		return nil, err
	}
	return map[string]any{"routines": list}, nil
}

type refParams struct {
	ID string `json:"id"`
}

func (s *Service) get(params json.RawMessage) (any, error) {
	var p refParams
	_ = json.Unmarshal(params, &p)
	r, ok := s.lookup(p.ID)
	if !ok {
		return nil, fmt.Errorf("no routine %q", p.ID)
	}
	return map[string]any{"routine": r}, nil
}

// save upserts a routine. With "replace" set, the routine of that id is
// replaced (renames keep the place in the list); without it a routine with
// the same id is replaced, and a new one gets a unique id. Returns the
// saved routine and the previous version (null for a new one).
func (s *Service) save(params json.RawMessage) (any, error) {
	var p struct {
		Routine Routine `json:"routine"`
		Replace string  `json:"replace"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("invalid routine: %v", err)
	}
	r, err := Normalize(p.Routine)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	list, err := Load(s.path)
	if err != nil {
		s.mu.Unlock()
		return nil, err
	}
	at := -1
	if p.Replace != "" {
		at = Find(list, p.Replace)
	} else if p.Routine.ID != "" {
		for i := range list {
			if list[i].ID == r.ID {
				at = i
			}
		}
	}
	r.ID = UniqueID(list, r.ID, at)
	var previous *Routine
	if at >= 0 {
		prev := list[at]
		previous = &prev
		list[at] = r
	} else {
		list = append(list, r)
	}
	err = Save(s.path, list)
	s.mu.Unlock()
	if err != nil {
		return nil, err
	}
	s.broadcast(list)
	return map[string]any{"routine": r, "previous": previous}, nil
}

func (s *Service) remove(params json.RawMessage) (any, error) {
	var p refParams
	_ = json.Unmarshal(params, &p)
	s.mu.Lock()
	list, err := Load(s.path)
	if err != nil {
		s.mu.Unlock()
		return nil, err
	}
	i := Find(list, p.ID)
	if i < 0 {
		s.mu.Unlock()
		return nil, fmt.Errorf("no routine %q", p.ID)
	}
	gone := list[i]
	list = append(list[:i], list[i+1:]...)
	err = Save(s.path, list)
	s.mu.Unlock()
	if err != nil {
		return nil, err
	}
	s.broadcast(list)
	return map[string]any{"routine": gone, "index": i}, nil
}

// run executes a saved routine ("id") or an unsaved one ("routine", the
// editor's test run). "quiet" skips the failure notification.
func (s *Service) run(params json.RawMessage) (any, error) {
	var p struct {
		ID      string   `json:"id"`
		Routine *Routine `json:"routine"`
		Quiet   bool     `json:"quiet"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	var r Routine
	if p.Routine != nil {
		n, err := Normalize(*p.Routine)
		if err != nil {
			return nil, err
		}
		r = n
	} else {
		found, ok := s.lookup(p.ID)
		if !ok {
			return nil, fmt.Errorf("no routine %q", p.ID)
		}
		r = found
	}
	rep := s.Run(r)
	if !rep.OK && !p.Quiet && s.notify != nil {
		s.notify("Routine "+r.Name+" failed", failureText(rep))
	}
	return rep, nil
}

// Run executes r and publishes the report (routines.report).
func (s *Service) Run(r Routine) Report {
	ctx, cancel := context.WithTimeout(context.Background(), runCap)
	defer cancel()
	s.send("routines.running", map[string]any{"id": r.ID, "name": r.Name})
	rep := s.exec.Run(ctx, r)
	s.send("routines.report", rep)
	return rep
}

func failureText(rep Report) string {
	for _, st := range rep.Steps {
		if st.Status == StatusFailed {
			return fmt.Sprintf("Step %d (%s): %s", st.Index+1, st.Label, st.Error)
		}
	}
	return "Stopped"
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs[sub] = struct{}{}
	s.subsMu.Unlock()
	if list, err := Load(s.path); err == nil {
		sub.Send("routines.state", map[string]any{"routines": list})
	}
	<-sub.StopCh()
	s.subsMu.Lock()
	delete(s.subs, sub)
	s.subsMu.Unlock()
}

func (s *Service) send(kind string, data any) {
	s.subsMu.Lock()
	defer s.subsMu.Unlock()
	for sub := range s.subs {
		sub.Send(kind, data)
	}
}

func (s *Service) broadcast(list []Routine) {
	s.send("routines.state", map[string]any{"routines": list})
}
