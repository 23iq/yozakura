// Package focus mirrors the shell's focus mode (modules/services/FocusMode.qml
// owns it: Do Not Disturb + a "Focus" timer) so the CLI and the MCP tools
// can read it. The shell reports {active, timerId, startedAt} with
// focus.set whenever it changes; focus.get adds the timer's end and time
// left from the timers service.
package focus

import (
	"encoding/json"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/svc/timers"
)

// State is what the shell reports.
type State struct {
	Active    bool   `json:"active"`
	TimerID   string `json:"timerId"`
	StartedAt int64  `json:"startedAt"` // unix ms
}

// Status is focus.get: the state plus the timer's progress.
type Status struct {
	Active      bool   `json:"active"`
	Known       bool   `json:"known"` // the shell reported since the daemon started
	StartedAt   int64  `json:"startedAt,omitempty"`
	EndsAt      int64  `json:"endsAt,omitempty"` // unix ms; 0 when paused or unknown
	LeftMs      int64  `json:"leftMs"`
	MinutesLeft int    `json:"minutesLeft"`
	Paused      bool   `json:"paused,omitempty"`
	TimerID     string `json:"timerId,omitempty"`
}

// Service is the "focus" IPC service.
type Service struct {
	mu    sync.Mutex
	st    State
	known bool
	timer func(id string) (timers.Timer, bool)
	now   func() time.Time
}

// NewService looks the focus timer up with timer (nil: no progress).
func NewService(timer func(id string) (timers.Timer, bool)) *Service {
	return &Service{timer: timer, now: time.Now}
}

// Register exposes focus.set and focus.get.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "focus",
		Methods: map[string]ipc.HandlerFunc{
			"set": s.handleSet,
			"get": func(json.RawMessage) (any, error) { return s.Status(), nil },
		},
	})
}

func (s *Service) handleSet(params json.RawMessage) (any, error) {
	var st State
	if err := json.Unmarshal(params, &st); err != nil {
		return nil, err
	}
	s.Set(st)
	return s.Status(), nil
}

// Set stores the shell's state.
func (s *Service) Set(st State) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !st.Active {
		st = State{}
	}
	s.st, s.known = st, true
}

// Status is the current focus state with the timer's progress.
func (s *Service) Status() Status {
	s.mu.Lock()
	st, known := s.st, s.known
	s.mu.Unlock()
	out := Status{Active: st.Active, Known: known}
	if !st.Active {
		return out
	}
	out.StartedAt, out.TimerID = st.StartedAt, st.TimerID
	if s.timer == nil || st.TimerID == "" {
		return out
	}
	t, ok := s.timer(st.TimerID)
	if !ok {
		return out
	}
	switch t.State {
	case timers.StateRunning:
		out.EndsAt = t.EndsAt
		out.LeftMs = max(0, t.EndsAt-s.now().UnixMilli())
	case timers.StatePaused:
		out.Paused, out.LeftMs = true, t.LeftMs
	}
	out.MinutesLeft = int((out.LeftMs + 59_999) / 60_000)
	return out
}
