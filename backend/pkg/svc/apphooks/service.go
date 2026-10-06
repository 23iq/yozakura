// Package apphooks is the IPC service that connects third-party apps to the
// generated theme files (see backend/pkg/apphooks).
//
// IPC (service "apphooks"):
//
//	status {}            -> {<id>: Status}
//	ensure {ids: [...]}  -> {<id>: Status} for the ids; applies only hooks
//	                        whose state is "disconnected" (never touches
//	                        absent / managed / error / connected apps)
//	apply  {id}          -> Status
//	revert {id}          -> Status
package apphooks

import (
	"encoding/json"
	"errors"
	"sync"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/ipc"
)

// Service is the apphooks IPC service.
type Service struct {
	env apphooks.Env
	mu  sync.Mutex // one hook edit at a time
}

// NewService uses the real environment.
func NewService() *Service { return &Service{env: apphooks.DefaultEnv()} }

func newService(env apphooks.Env) *Service { return &Service{env: env} }

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "apphooks",
		Methods: map[string]ipc.HandlerFunc{
			"status": s.status,
			"ensure": s.ensure,
			"apply":  s.apply,
			"revert": s.revert,
		},
		Async: map[string]bool{"status": true, "ensure": true, "apply": true, "revert": true},
	})
}

func (s *Service) status(json.RawMessage) (any, error) {
	return apphooks.Statuses(s.env), nil
}

func (s *Service) ensure(params json.RawMessage) (any, error) {
	var p struct {
		IDs []string `json:"ids"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	out := map[string]apphooks.Status{}
	for _, id := range p.IDs {
		h, ok := apphooks.Get(id)
		if !ok {
			continue
		}
		st := h.Status(s.env)
		if st.State == apphooks.StateDisconnected {
			st, _ = h.Apply(s.env) // the status carries any failure
		}
		out[id] = st
	}
	return out, nil
}

func (s *Service) one(params json.RawMessage, revert bool) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.ID == "" {
		return nil, errors.New("id is required")
	}
	h, ok := apphooks.Get(p.ID)
	if !ok && revert {
		// apps without a hook have nothing to revert: idempotent
		return apphooks.Status{ID: p.ID, State: apphooks.StateAbsent}, nil
	}
	if !ok {
		return nil, errors.New("unknown app: " + p.ID)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if revert {
		st, _ := h.Revert(s.env)
		return st, nil
	}
	st, _ := h.Apply(s.env)
	return st, nil
}

func (s *Service) apply(params json.RawMessage) (any, error) { return s.one(params, false) }

func (s *Service) revert(params json.RawMessage) (any, error) { return s.one(params, true) }
