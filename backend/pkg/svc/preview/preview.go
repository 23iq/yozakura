// Package preview relays staged settings from a separate Settings window
// process (performance.separateWindows, pkg/svc/windows) to the main shell,
// so a staged change previews on the desktop as it does with the window
// in-process.
//
// The window stages a change in its own Config (snapshot + auto-save paused,
// GlobalStates.mark*Changed) and sends preview.set {owner, key, value}; the
// main shell (modules/services/PreviewSink.qml, the only subscriber) applies
// it to its in-memory Config through the same staging, so nothing of it is
// written there. Apply: the window writes the files and sends
// preview.commit; the main shell drops its snapshot without restoring it
// (the reload of the written files brings the same values). Discard (or
// closing without applying): the window restores its snapshot and sends
// preview.discard; the main shell restores its own. When the window process
// is gone (crash, kill) the windows service calls OwnerGone and the main
// shell is told to discard. The daemon keeps the staged values, so a main
// shell that restarts while the window is open gets them again on
// subscribe.
package preview

import (
	"encoding/json"
	"errors"
	"sync"

	"yozakura/backend/pkg/ipc"
)

// Entry is one staged key.
type Entry struct {
	Owner string          `json:"owner"`
	Key   string          `json:"key"`
	Value json.RawMessage `json:"value"`
}

// Event payload of preview.discard / preview.commit.
type Done struct {
	Owner string `json:"owner"`
}

// Service is the "preview" IPC service.
type Service struct {
	mu     sync.Mutex
	staged []Entry // in the order they were set, one per (owner, key)
	subs   map[*ipc.Subscriber]struct{}
}

// NewService returns an empty relay.
func NewService() *Service {
	return &Service{subs: map[*ipc.Subscriber]struct{}{}}
}

// Register exposes preview.set/discard/commit/state and the stream.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "preview",
		Methods: map[string]ipc.HandlerFunc{
			"set":     s.handleSet,
			"discard": s.handleDone(s.Discard),
			"commit":  s.handleDone(s.Commit),
			"state":   func(json.RawMessage) (any, error) { return map[string]any{"staged": s.Staged()}, nil },
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) handleSet(raw json.RawMessage) (any, error) {
	var e Entry
	if err := json.Unmarshal(raw, &e); err != nil {
		return nil, err
	}
	if e.Owner == "" || e.Key == "" {
		return nil, errors.New("preview.set: missing owner or key")
	}
	if len(e.Value) == 0 {
		e.Value = json.RawMessage("null")
	}
	s.Set(e)
	return map[string]any{"ok": true}, nil
}

func (s *Service) handleDone(fn func(owner string) bool) ipc.HandlerFunc {
	return func(raw json.RawMessage) (any, error) {
		var d Done
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &d); err != nil {
				return nil, err
			}
		}
		if d.Owner == "" {
			return nil, errors.New("preview: missing owner")
		}
		return map[string]any{"ok": fn(d.Owner)}, nil
	}
}

// Set stages e (replacing the owner's earlier value of the key) and sends
// it to the main shell.
func (s *Service) Set(e Entry) {
	s.mu.Lock()
	defer s.mu.Unlock()
	replaced := false
	for i := range s.staged {
		if s.staged[i].Owner == e.Owner && s.staged[i].Key == e.Key {
			s.staged[i].Value = e.Value
			replaced = true
			break
		}
	}
	if !replaced {
		s.staged = append(s.staged, e)
	}
	s.sendLocked("preview.set", e)
}

// Discard drops what owner staged; the main shell restores its snapshot.
func (s *Service) Discard(owner string) bool { return s.end(owner, "preview.discard") }

// Commit drops what owner staged; the main shell keeps the values (the
// owner wrote them to disk).
func (s *Service) Commit(owner string) bool { return s.end(owner, "preview.commit") }

// OwnerGone is Discard for a window process that exited.
func (s *Service) OwnerGone(owner string) { s.end(owner, "preview.discard") }

// end drops owner's entries and tells the main shell; the entries of any
// other owner are sent again after it, since the shell's discard restores
// a whole snapshot. Reports whether owner had staged anything (the event
// is sent either way: the shell may hold a staging the daemon never saw,
// e.g. after a daemon restart).
func (s *Service) end(owner, event string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	kept := s.staged[:0]
	had := false
	for _, e := range s.staged {
		if e.Owner == owner {
			had = true
			continue
		}
		kept = append(kept, e)
	}
	s.staged = kept
	s.sendLocked(event, Done{Owner: owner})
	for _, e := range s.staged {
		s.sendLocked("preview.set", e)
	}
	return had
}

// Staged is a copy of the staged entries, in order.
func (s *Service) Staged() []Entry {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]Entry(nil), s.staged...)
}

func (s *Service) sendLocked(event string, data any) {
	for sub := range s.subs {
		sub.Send(event, data)
	}
}

// subscribe replays the staged values to a (re)started main shell.
func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	for _, e := range s.staged {
		sub.Send("preview.set", e)
	}
	s.mu.Unlock()
	<-sub.StopCh()
	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
}
