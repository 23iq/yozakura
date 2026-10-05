package agents

import (
	"encoding/json"
	"errors"
	"sync"

	"yozakura/backend/pkg/ipc"
)

// Service exposes the Manager as the "agents" IPC service.
type Service struct {
	m    *Manager
	mu   sync.Mutex
	subs map[*ipc.Subscriber]struct{}
}

// NewService wraps a manager and routes its broadcasts to subscribers.
func NewService(m *Manager) *Service {
	s := &Service{m: m, subs: map[*ipc.Subscriber]struct{}{}}
	m.SetBroadcast(s.push)
	return s
}

// Manager returns the wrapped manager (daemon wiring).
func (s *Service) Manager() *Manager { return s.m }

func (s *Service) push(service string, data any) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for sub := range s.subs {
		sub.Send(service, data)
	}
}

// Register wires the service into the IPC server.
func (s *Service) Register(srv *ipc.Server) { srv.Register(s.ipcService()) }

func (s *Service) ipcService() *ipc.Service {
	return &ipc.Service{
		Name: "agents",
		Methods: map[string]ipc.HandlerFunc{
			"list_agents": func(json.RawMessage) (any, error) { return s.m.ListAgents(), nil },
			"configure":   s.configure,
			"create":      s.create,
			"send":        s.send,
			"respond":     s.respond,
			"cancel":      s.byID(s.m.Cancel),
			"close":       s.byID(s.m.CloseSession),
			"delete":      s.byID(s.m.Delete),
			"update":      s.update,
			"sessions":    func(json.RawMessage) (any, error) { return s.m.Sessions(), nil },
			"events":      s.events,
		},
		Subscribe: s.subscribe,
		// Both run `<agent> --version` probes (up to 4 s each).
		Async: map[string]bool{"list_agents": true, "configure": true},
	}
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	s.mu.Unlock()
	sub.Send("agents.sessions", s.m.Sessions())
	<-sub.StopCh()
	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
}

func decode(params json.RawMessage, v any) error {
	if len(params) == 0 {
		return errors.New("missing params")
	}
	return json.Unmarshal(params, v)
}

var ok = map[string]any{"ok": true}

func (s *Service) configure(params json.RawMessage) (any, error) {
	var c Config
	if err := decode(params, &c); err != nil {
		return nil, err
	}
	s.m.Configure(c)
	return ok, nil
}

func (s *Service) create(params json.RawMessage) (any, error) {
	var p CreateParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Create(p)
}

func (s *Service) send(params json.RawMessage) (any, error) {
	var p struct {
		Session string   `json:"session"`
		Text    string   `json:"text"`
		Images  []string `json:"images"`
	}
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	if err := s.m.Send(p.Session, p.Text, p.Images); err != nil {
		return nil, err
	}
	return ok, nil
}

func (s *Service) respond(params json.RawMessage) (any, error) {
	var p struct {
		Session  string `json:"session"`
		Request  string `json:"request"`
		Decision string `json:"decision"`
	}
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	switch p.Decision {
	case DecisionAllow, DecisionAllowSession, DecisionDeny:
	default:
		return nil, errors.New("decision must be allow, allow_session or deny")
	}
	if err := s.m.Respond(p.Session, p.Request, p.Decision); err != nil {
		return nil, err
	}
	return ok, nil
}

func (s *Service) byID(fn func(string) error) ipc.HandlerFunc {
	return func(params json.RawMessage) (any, error) {
		var p struct {
			Session string `json:"session"`
		}
		if err := decode(params, &p); err != nil {
			return nil, err
		}
		if err := fn(p.Session); err != nil {
			return nil, err
		}
		return ok, nil
	}
}

func (s *Service) update(params json.RawMessage) (any, error) {
	var p UpdateParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Update(p)
}

func (s *Service) events(params json.RawMessage) (any, error) {
	var p struct {
		Session string `json:"session"`
		Since   int64  `json:"since"`
	}
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	evs, last, err := s.m.Events(p.Session, p.Since)
	if err != nil {
		return nil, err
	}
	return map[string]any{"events": evs, "last": last}, nil
}
