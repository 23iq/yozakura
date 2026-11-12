// Package preview relays staged settings between the processes of the
// shell when Settings and the setup wizard run as their own processes
// (performance.separateWindows, pkg/svc/windows), so a staged change
// previews on the desktop and in the other window as it does in-process.
//
// In-process there is one Config and one staging (the GlobalStates
// snapshots): whatever Settings or the wizard stage is the same set of
// unsaved changes, Apply anywhere writes all of it and Discard anywhere
// restores all of it. This relay keeps that: it is one shared staging, not
// one per window. A window stages a change in its own Config (snapshot +
// auto-save paused) and sends preview.set {owner, key, value}; every other
// process (the main shell's and the other window's PreviewSink.qml) applies
// it with the same staging, so nothing of it is written and every window
// shows it as unsaved. Commit (Apply) or Discard by any owner ends the
// whole staging: preview.commit / preview.discard {owner} tells every
// other process to drop / restore its snapshots. On commit the main shell
// writes the files: its Config holds every staged value and the changes
// the desktop made meanwhile (widget positions, dashboard cells), exactly
// what Apply writes in-process. It answers preview.written {id}, which
// preview.commit returns to the window as "written"; with no answer within
// AckWait (no main shell) the window writes what it changed itself. When a window process is
// gone (crash, kill, closed without applying) and no other window runs,
// the staging is discarded; while another window runs it stays, shown
// there as unsaved changes, to apply or discard. The daemon keeps the
// staged values, so a process that (re)starts meanwhile (the main shell, a
// window opened later) gets them on subscribe.
package preview

import (
	"encoding/json"
	"errors"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
)

// Entry is one staged key.
type Entry struct {
	Owner string          `json:"owner"`
	Key   string          `json:"key"`
	Value json.RawMessage `json:"value"`
}

// Event payload of preview.discard / preview.commit (ID: the commit the
// main shell answers with preview.written).
type Done struct {
	Owner string `json:"owner"`
	ID    uint64 `json:"id,omitempty"`
}

// Written is preview.written: the main shell wrote the files of commit ID.
type Written struct {
	ID uint64 `json:"id"`
}

// AckWait is how long preview.commit waits for the main shell to write.
var AckWait = 2 * time.Second

// Service is the "preview" IPC service.
type Service struct {
	mu     sync.Mutex
	staged []Entry // in the order they were set, one per (owner, key)
	subs   map[*ipc.Subscriber]struct{}
	acks   map[uint64]chan struct{}
	nextID uint64
}

// NewService returns an empty relay.
func NewService() *Service {
	return &Service{subs: map[*ipc.Subscriber]struct{}{}, acks: map[uint64]chan struct{}{}}
}

// Register exposes preview.set/discard/commit/state and the stream.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "preview",
		Methods: map[string]ipc.HandlerFunc{
			"set":     s.handleSet,
			"discard": s.handleDone(s.Discard),
			"commit":  s.handleCommit,
			"written": s.handleWritten,
			"state":   func(json.RawMessage) (any, error) { return map[string]any{"staged": s.Staged()}, nil },
		},
		Subscribe: s.subscribe,
		// commit is ordered: it ends the staging after every preview.set
		// the window sent before it on its connection (an async commit
		// could overtake one and lose it); only its wait for the main
		// shell's preview.written runs off the connection (ipc.Deferred).
	})
}

func (s *Service) handleCommit(raw json.RawMessage) (any, error) {
	var d Done
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, err
		}
	}
	if d.Owner == "" {
		return nil, errors.New("preview: missing owner")
	}
	had, wait := s.startCommit(d.Owner)
	return ipc.Deferred(func() (any, error) {
		return map[string]any{"ok": had, "written": wait()}, nil
	}), nil
}

func (s *Service) handleWritten(raw json.RawMessage) (any, error) {
	var w Written
	if err := json.Unmarshal(raw, &w); err != nil {
		return nil, err
	}
	return map[string]any{"ok": s.Ack(w.ID)}, nil
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

// Commit ends the staging (every owner's: it is one); the other processes
// keep the values and the main shell writes them. It does not wait.
func (s *Service) Commit(owner string) bool {
	had, _ := s.commit(owner)
	return had
}

// CommitAndWait is Commit, then waits up to AckWait for the main shell to
// report it wrote the files (written). Nobody subscribed: false at once.
func (s *Service) CommitAndWait(owner string) (had, written bool) {
	had, wait := s.startCommit(owner)
	return had, wait()
}

// startCommit ends the staging and broadcasts the commit now; wait then
// waits up to AckWait for the main shell's answer.
func (s *Service) startCommit(owner string) (had bool, wait func() bool) {
	had, id := s.commit(owner)
	s.mu.Lock()
	ch, ok := s.acks[id]
	s.mu.Unlock()
	return had, func() bool {
		if !ok {
			return false
		}
		t := time.NewTimer(AckWait)
		defer t.Stop()
		written := false
		select {
		case <-ch:
			written = true
		case <-t.C:
		}
		s.mu.Lock()
		delete(s.acks, id)
		s.mu.Unlock()
		return written
	}
}

// Ack records the main shell's preview.written for commit id.
func (s *Service) Ack(id uint64) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	ch, ok := s.acks[id]
	if ok {
		delete(s.acks, id)
		close(ch)
	}
	return ok
}

func (s *Service) commit(owner string) (bool, uint64) {
	s.mu.Lock()
	defer s.mu.Unlock()
	had := len(s.staged) > 0
	s.staged = nil
	s.nextID++
	id := s.nextID
	if len(s.subs) > 0 {
		s.acks[id] = make(chan struct{})
	}
	s.sendLocked("preview.commit", Done{Owner: owner, ID: id})
	return had, id
}

// OwnerGone is called when the window process of owner exited. With
// another window still running the staging stays (that window shows it and
// can apply or discard it); otherwise it is discarded, so no staged value
// stays live on the desktop with no window left to discard it.
func (s *Service) OwnerGone(owner string, othersRunning bool) {
	s.mu.Lock()
	n := len(s.staged)
	s.mu.Unlock()
	if othersRunning || n == 0 {
		return
	}
	s.end(owner, "preview.discard")
}

// end drops the whole staging and tells every process. Reports whether
// anything was staged (the event is sent either way: a process may hold a
// staging the daemon never saw, e.g. after a daemon restart).
func (s *Service) end(owner, event string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	had := len(s.staged) > 0
	s.staged = nil
	s.sendLocked(event, Done{Owner: owner})
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
