package tasks

import (
	"encoding/json"
	"errors"
	"sync"

	"yozakura/backend/pkg/ipc"
)

// Service exposes the Manager as the "tasks" IPC service.
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

// Manager returns the wrapped manager.
func (s *Service) Manager() *Manager { return s.m }

func (s *Service) push(kind string, data any) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for sub := range s.subs {
		sub.Send(kind, data)
	}
}

// Register wires the service into the IPC server.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "tasks",
		Methods: map[string]ipc.HandlerFunc{
			"create":         s.create,
			"list":           s.list,
			"get":            s.get,
			"plan.update":    s.planUpdate,
			"run":            s.run,
			"cancel":         s.byID(s.m.Cancel),
			"followup":       s.followup,
			"accept":         s.accept,
			"discard":        s.discard,
			"delete":         s.delete,
			"open":           s.open,
			"diff":           s.diff,
			"debug":          s.debug,
			"activity":       func(json.RawMessage) (any, error) { return s.m.Activity(), nil },
			"configure":      s.configure,
			"settings":       func(json.RawMessage) (any, error) { return s.m.Settings(), nil },
			"project.get":    s.projectGet,
			"project.set":    s.projectSet,
			"templates.list": s.templatesList,
			"templates.get":  s.templatesGet,
			"git":            s.git,
		},
		Subscribe: s.subscribe,
		// git worktrees, checks and git status run child processes.
		Async: map[string]bool{"create": true, "accept": true, "discard": true, "delete": true, "diff": true,
			"git": true, "project.get": true, "project.set": true, "templates.get": true, "cancel": true},
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	s.mu.Unlock()
	sub.Send("tasks.list", s.m.List(""))
	sub.Send("tasks.activity", s.m.Activity())
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

type idParams struct {
	ID    string   `json:"id"`
	Run   int      `json:"run"`
	Text  string   `json:"text"`
	Steps []string `json:"steps"`
	Lines int      `json:"lines"`
	Dir   string   `json:"dir"`
	Name  string   `json:"name"`
}

func (s *Service) byID(fn func(string) (Task, error)) ipc.HandlerFunc {
	return func(params json.RawMessage) (any, error) {
		var p idParams
		if err := decode(params, &p); err != nil {
			return nil, err
		}
		return fn(p.ID)
	}
}

func (s *Service) create(params json.RawMessage) (any, error) {
	var p CreateParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Create(p)
}

func (s *Service) list(params json.RawMessage) (any, error) {
	var p idParams
	if len(params) > 0 {
		_ = json.Unmarshal(params, &p)
	}
	return s.m.List(p.Dir), nil
}

func (s *Service) get(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Get(p.ID)
}

func (s *Service) planUpdate(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.UpdatePlan(p.ID, p.Steps)
}

func (s *Service) run(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Run(p.ID, p.Steps)
}

func (s *Service) followup(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Followup(p.ID, p.Run, p.Text)
}

func (s *Service) accept(params json.RawMessage) (any, error) {
	var p AcceptParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Accept(p)
}

func (s *Service) discard(params json.RawMessage) (any, error) {
	var p struct {
		ID  string `json:"id"`
		Run *int   `json:"run"`
	}
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	idx := -1
	if p.Run != nil {
		idx = *p.Run
	}
	return s.m.Discard(p.ID, idx)
}

func (s *Service) delete(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	if err := s.m.Delete(p.ID); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) open(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	if err := s.m.Open(p.ID, p.Run); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) diff(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	d, err := s.m.Diff(p.ID, p.Run)
	if err != nil {
		return nil, err
	}
	return map[string]any{"diff": d}, nil
}

func (s *Service) debug(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Debug(p.ID, p.Run, p.Lines)
}

func (s *Service) configure(params json.RawMessage) (any, error) {
	var st Settings
	if err := decode(params, &st); err != nil {
		return nil, err
	}
	return s.m.Configure(st), nil
}

func (s *Service) projectGet(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.Project(p.Dir)
}

func (s *Service) projectSet(params json.RawMessage) (any, error) {
	var p ProjectPatch
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	return s.m.SetProject(p)
}

func (s *Service) templatesList(params json.RawMessage) (any, error) {
	var p idParams
	if len(params) > 0 {
		_ = json.Unmarshal(params, &p)
	}
	dir := ""
	if p.Dir != "" {
		dir, _ = projectRoot(p.Dir, false)
	}
	return ListTemplates(s.m.opt.Templates, dir), nil
}

func (s *Service) templatesGet(params json.RawMessage) (any, error) {
	var p struct {
		Name   string            `json:"name"`
		Dir    string            `json:"dir"`
		Render bool              `json:"render"`
		Vars   map[string]string `json:"vars"`
	}
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	dir := ""
	if p.Dir != "" {
		dir, _ = projectRoot(p.Dir, false)
	}
	t, err := GetTemplate(s.m.opt.Templates, dir, p.Name)
	if err != nil {
		return nil, err
	}
	if p.Render {
		t.Body = s.m.RenderIn(dir, t.Body, p.Vars)
	}
	return t, nil
}

func (s *Service) git(params json.RawMessage) (any, error) {
	var p idParams
	if err := decode(params, &p); err != nil {
		return nil, err
	}
	if p.Dir == "" {
		return nil, errors.New("dir is required")
	}
	return Summarize(p.Dir), nil
}
