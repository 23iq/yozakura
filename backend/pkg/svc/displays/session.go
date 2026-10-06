package displays

import (
	"errors"
	"fmt"
	"math"
	"strconv"
	"sync"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
)

// RevertAfter is how long a live display change waits for Keep.
const RevertAfter = 15 * time.Second

// Session states.
const (
	StatePending  = "pending"
	StateKept     = "kept"
	StateReverted = "reverted"
)

// Applier applies one output configuration live.
type Applier interface {
	Apply(ipc.OutputConfig) error
}

// Session is one apply → confirm → revert cycle. Live is false when the
// compositor cannot apply outputs at runtime (Mango): the change only takes
// effect once the shell persists it, and reverting applies nothing.
type Session struct {
	ID                  string
	Snapshot, Candidate []ipc.OutputConfig
	Deadline            time.Time
	State               string
	Live                bool
}

// Manager holds at most one session. It is clock-free: callers pass now,
// so the timer lives in the service and tests drive time directly.
type Manager struct {
	mu      sync.Mutex
	applier Applier
	cur     *Session
	seq     int
}

// NewManager returns a Manager applying through a.
func NewManager(a Applier) *Manager { return &Manager{applier: a} }

// Start applies cand and opens a pending session that reverts to snap at
// now+RevertAfter. A pending session is reverted first. If applying fails,
// snap is re-applied at once and the reverted session is returned with the
// error.
func (m *Manager) Start(now time.Time, snap, cand []ipc.OutputConfig) (*Session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.cur != nil && m.cur.State == StatePending {
		// snap was read while the old candidate was live: restore the
		// old session's snapshot for outputs it already covered.
		snap = carrySnapshot(m.cur.Snapshot, snap, cand)
		_ = m.revertLocked()
	}
	m.seq++
	s := &Session{
		ID:       strconv.FormatInt(now.UnixNano(), 36) + "-" + strconv.Itoa(m.seq),
		Snapshot: snap, Candidate: cand,
		Deadline: now.Add(RevertAfter),
		State:    StatePending,
		Live:     true,
	}
	m.cur = s
	for i, c := range cand {
		err := m.applier.Apply(c)
		if err == nil {
			continue
		}
		if i == 0 && errors.Is(err, ipc.ErrNotSupported) {
			s.Live = false
			break
		}
		_ = m.revertLocked()
		return m.copyLocked(), fmt.Errorf("apply %s: %w", c.Name, err)
	}
	return m.copyLocked(), nil
}

// Tick reverts the pending session once its deadline has passed and
// returns it; otherwise nil.
func (m *Manager) Tick(now time.Time) *Session {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.cur == nil || m.cur.State != StatePending || now.Before(m.cur.Deadline) {
		return nil
	}
	_ = m.revertLocked()
	return m.copyLocked()
}

// Keep confirms the pending session id and returns it.
func (m *Manager) Keep(id string) (*Session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := m.pendingLocked(id); err != nil {
		return nil, err
	}
	m.cur.State = StateKept
	return m.copyLocked(), nil
}

// Revert re-applies the snapshot of the pending session id.
func (m *Manager) Revert(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := m.pendingLocked(id); err != nil {
		return err
	}
	return m.revertLocked()
}

// Current returns a copy of the latest session, or nil.
func (m *Manager) Current() *Session {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.copyLocked()
}

// Remaining is the whole seconds (rounded up) left on the pending session.
func (m *Manager) Remaining(now time.Time) int {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.cur == nil || m.cur.State != StatePending {
		return 0
	}
	left := m.cur.Deadline.Sub(now).Seconds()
	if left <= 0 {
		return 0
	}
	return int(math.Ceil(left))
}

func (m *Manager) pendingLocked(id string) error {
	if m.cur == nil || m.cur.ID != id {
		return fmt.Errorf("unknown display session %q", id)
	}
	if m.cur.State != StatePending {
		return fmt.Errorf("display session %q is already %s", id, m.cur.State)
	}
	return nil
}

// revertLocked applies the snapshot (live sessions only) and marks the
// session reverted. Every output is attempted; the first error is returned.
func (m *Manager) revertLocked() error {
	s := m.cur
	s.State = StateReverted
	if !s.Live {
		return nil
	}
	var first error
	for _, c := range s.Snapshot {
		if err := m.applier.Apply(c); err != nil && first == nil {
			first = fmt.Errorf("revert %s: %w", c.Name, err)
		}
	}
	return first
}

func (m *Manager) copyLocked() *Session {
	if m.cur == nil {
		return nil
	}
	c := *m.cur
	return &c
}

// carrySnapshot builds the snapshot of a session that replaces a pending
// one: per candidate output, the old (pre-change) snapshot entry wins over
// the freshly read one, which only shows the unconfirmed candidate.
func carrySnapshot(old, fresh, cand []ipc.OutputConfig) []ipc.OutputConfig {
	byName := map[string]ipc.OutputConfig{}
	for _, c := range fresh {
		byName[c.Name] = c
	}
	for _, c := range old {
		byName[c.Name] = c
	}
	var out []ipc.OutputConfig
	for _, c := range cand {
		if s, ok := byName[c.Name]; ok {
			out = append(out, s)
		}
	}
	return out
}
