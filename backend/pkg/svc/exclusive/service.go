// Package exclusive is the "exclusive" IPC service: make Yozakura the only
// shell on a Hyprland session and undo it (see backend/pkg/exclusive).
//
// IPC (service "exclusive"):
//
//	status  {}            -> {active, backup, disabledUnits, compositor, reason?}
//	plan    {}            -> {entry, hyprDir, backupDir, units, monitors, keyboard,
//	                          userFile, alreadyDone}  (what enable would do)
//	enable  {}            -> Status (no-op while active; rolled back on failure)
//	restore {from?}       -> Status + {replaced, previous}
//
// enable and restore touch files, systemd and the compositor, so they run
// async; every method fails with "not supported" off Hyprland.
package exclusive

import (
	"encoding/json"
	"sync"

	"yozakura/backend/pkg/exclusive"
	"yozakura/backend/pkg/ipc"
)

// Service is the exclusive IPC service. opts builds the environment per
// call, so tests inject a temporary home and fakes.
type Service struct {
	opts func() exclusive.Options
	mu   sync.Mutex // one enable/restore at a time
}

// NewService uses the real host.
func NewService() *Service { return &Service{opts: Host} }

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "exclusive",
		Methods: map[string]ipc.HandlerFunc{
			"status": s.status, "plan": s.plan, "enable": s.enable, "restore": s.restore,
		},
		Async: map[string]bool{"status": true, "plan": true, "enable": true, "restore": true},
	})
}

func (s *Service) status(json.RawMessage) (any, error) {
	return exclusive.GetStatus(s.opts()), nil
}

func (s *Service) plan(json.RawMessage) (any, error) {
	return exclusive.Preview(s.opts())
}

func (s *Service) enable(json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	st, err := exclusive.Enable(s.opts())
	if err != nil {
		return nil, err
	}
	return st, nil
}

func (s *Service) restore(params json.RawMessage) (any, error) {
	var p struct {
		From string `json:"from"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	st, err := exclusive.Restore(s.opts(), p.From)
	if err != nil {
		return nil, err
	}
	return st, nil
}
