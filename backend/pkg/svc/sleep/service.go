package sleep

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"sync"

	"github.com/godbus/dbus/v5"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/proc"
)

// Service monitors login1 PrepareForSleep and Session.Lock signals,
// pushing SUSPEND/WAKE/LOCK events and running configured commands.
// Replaces sleep_monitor.sh and loginlock.sh.
type Service struct {
	conn *dbus.Conn
	// session is this login session's object path, resolved on the first
	// subscription (login1 calls stay off the daemon's start); only its
	// Lock counts. "" when it could not be resolved: every session's Lock
	// counts, as before.
	session     dbus.ObjectPath
	sessionOnce sync.Once
	resolve     func() dbus.ObjectPath
	run         func(cmd string) // runDetached; tests record instead

	mu          sync.Mutex // guards the commands (setCommands vs the signal loop)
	beforeSleep string
	afterSleep  string
	lockCMD     string
}

func NewService() (*Service, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, fmt.Errorf("system bus: %w", err)
	}
	return newService(conn), nil
}

func newService(conn *dbus.Conn) *Service {
	return &Service{conn: conn, resolve: func() dbus.ObjectPath { return ownSession(conn) }, run: runDetached}
}

// ownLockPath is the session whose Lock counts ("" = any).
func (s *Service) ownLockPath() dbus.ObjectPath {
	s.sessionOnce.Do(func() {
		if s.resolve != nil {
			s.session = s.resolve()
		}
	})
	return s.session
}

func (s *Service) Close() {
	if s.conn != nil {
		s.conn.Close()
	}
}

// commands is a consistent snapshot of the configured commands.
func (s *Service) commands() (before, after, lock string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.beforeSleep, s.afterSleep, s.lockCMD
}

// setCommands stores the commands present in params; an empty string
// clears one (no command runs), an absent field keeps it.
func (s *Service) setCommands(params json.RawMessage) (any, error) {
	var p struct {
		Before *string `json:"before"`
		After  *string `json:"after"`
		Lock   *string `json:"lock"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if p.Before != nil {
		s.beforeSleep = *p.Before
	}
	if p.After != nil {
		s.afterSleep = *p.After
	}
	if p.Lock != nil {
		s.lockCMD = *p.Lock
	}
	return "ok", nil
}

// Register wires the service into the server.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "sleep",
		Methods: map[string]ipc.HandlerFunc{
			"setCommands": s.setCommands,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	if s.conn == nil {
		return
	}

	ch := make(chan *dbus.Signal, 16)
	s.conn.Signal(ch)
	defer s.conn.RemoveSignal(ch)

	if err := s.conn.AddMatchSignal(
		dbus.WithMatchObjectPath("/org/freedesktop/login1"),
		dbus.WithMatchInterface("org.freedesktop.login1.Manager"),
		dbus.WithMatchMember("PrepareForSleep"),
	); err != nil {
		return
	}
	lockMatch := []dbus.MatchOption{
		dbus.WithMatchInterface("org.freedesktop.login1.Session"),
		dbus.WithMatchMember("Lock"),
	}
	if own := s.ownLockPath(); own != "" {
		lockMatch = append(lockMatch, dbus.WithMatchObjectPath(own))
	}
	if err := s.conn.AddMatchSignal(lockMatch...); err != nil {
		return
	}

	for {
		select {
		case sig, ok := <-ch:
			if !ok {
				return
			}
			if sig == nil {
				continue
			}
			s.handle(sig, sub)
		case <-sub.StopCh():
			return
		}
	}
}

// handle reacts to one login1 signal.
func (s *Service) handle(sig *dbus.Signal, sub *ipc.Subscriber) {
	before, after, lock := s.commands()
	switch sig.Name {
	case "org.freedesktop.login1.Manager.PrepareForSleep":
		for _, body := range sig.Body {
			if v, ok := body.(bool); ok {
				if v {
					sub.Send("sleep", map[string]any{"event": "SUSPEND"})
					s.run(before)
				} else {
					sub.Send("sleep", map[string]any{"event": "WAKE"})
					s.run(after)
				}
			}
		}
	case "org.freedesktop.login1.Session.Lock":
		// the match is per session, but the system bus connection is
		// shared: other services' matches deliver signals here too
		if own := s.ownLockPath(); own != "" && sig.Path != own {
			return
		}
		sub.Send("sleep", map[string]any{"event": "LOCK"})
		s.run(lock)
	}
}

func runDetached(cmd string) {
	if cmd == "" {
		return
	}
	// reaped in the background: the daemon outlives every command it runs
	_ = proc.StartReaped(exec.CommandContext(context.Background(), "sh", "-c", cmd))
}
