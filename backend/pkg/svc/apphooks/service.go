// Package apphooks is the IPC service that connects third-party apps to the
// generated theme files (see backend/pkg/apphooks).
//
// IPC (service "apphooks"):
//
//	status {}            -> {<id>: Status}
//	ensure {ids: [...]}  -> {<id>: Status} for the ids; applies only hooks
//	                        whose state is "disconnected" (never touches
//	                        absent / managed / error / connected apps, nor
//	                        one with a theme of its own: user_theme)
//	apply  {id}          -> Status
//	revert {id}          -> Status
package apphooks

import (
	"encoding/json"
	"errors"
	"os"
	"sync"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/ipc"
)

// Service is the apphooks IPC service.
type Service struct {
	env apphooks.Env
	mu  sync.Mutex // one hook edit at a time
	// appsFile is apps.json: PostInstall honours apps.theming.<id>
	appsFile string
	// consented reports the upgrade consent migration ran
	// (migrate.EnsureAppHooksConsent); until then nothing is connected
	// automatically (ensure, PostInstall). nil: always.
	consented func() bool
}

// NewService uses the real environment; appsFile is apps.json, consented
// gates the automatic connection (see Service.consented).
func NewService(appsFile string, consented func() bool) *Service {
	return &Service{env: apphooks.DefaultEnv(), appsFile: appsFile, consented: consented}
}

// auto reports whether automatic connection is allowed now.
func (s *Service) auto() bool { return s.consented == nil || s.consented() }

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
	if !s.auto() {
		// no consent yet (e.g. a malformed apps.json): report, touch nothing
		out := map[string]apphooks.Status{}
		for _, id := range p.IDs {
			if h, ok := apphooks.Get(id); ok {
				out[id] = h.Status(s.env)
			}
		}
		return out, nil
	}
	return s.ensureIDs(p.IDs), nil
}

// ensureIDs is ensure under the service lock.
func (s *Service) ensureIDs(ids []string) map[string]apphooks.Status {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := map[string]apphooks.Status{}
	for _, id := range ids {
		h, ok := apphooks.Get(id)
		if !ok {
			continue
		}
		st := h.Status(s.env)
		// automatic: an app with a theme of its own waits for Connect
		if st.State == apphooks.StateDisconnected && !apphooks.UserOwnsTheme(st) {
			st, _ = h.Apply(s.env) // the status carries any failure
		}
		out[id] = st
	}
	return out
}

// PostInstall connects an app the extras installer just installed (catalog
// post "apphook:<id>") the way ensure does: only when apps.theming.<id> is
// on, never an app with a theme of its own, one edit at a time.
func (s *Service) PostInstall(id string) error {
	if _, ok := apphooks.Get(id); !ok {
		return errors.New("unknown app hook: " + id)
	}
	if !s.auto() || !themed(s.appsFile, id) {
		return nil
	}
	if st := s.ensureIDs([]string{id})[id]; st.State == apphooks.StateError {
		return errors.New(st.Reason)
	}
	return nil
}

// themed reads apps.theming.<id> from apps.json (missing: on, like the
// default; unreadable: off, nothing is touched).
func themed(appsFile, id string) bool {
	data, err := os.ReadFile(appsFile)
	if os.IsNotExist(err) {
		return true
	}
	var cfg struct {
		Theming map[string]any `json:"theming"`
	}
	if err != nil || json.Unmarshal(data, &cfg) != nil {
		return false
	}
	return cfg.Theming[id] != false
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
