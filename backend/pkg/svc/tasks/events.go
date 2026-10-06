package tasks

import (
	"strings"
	"sync"
	"time"

	"yozakura/backend/pkg/svc/agents"
)

// mailbox is an unbounded FIFO: the agents listener must never block, and
// no event (a done in particular) may be dropped.
type mailbox struct {
	mu     sync.Mutex
	items  []agents.Event
	signal chan struct{}
	done   bool
}

func newMailbox() *mailbox { return &mailbox{signal: make(chan struct{}, 1)} }

func (b *mailbox) put(ev agents.Event) {
	b.mu.Lock()
	if !b.done {
		b.items = append(b.items, ev)
	}
	b.mu.Unlock()
	select {
	case b.signal <- struct{}{}:
	default:
	}
}

// take blocks until events are available; ok is false once closed.
func (b *mailbox) take() ([]agents.Event, bool) {
	for {
		b.mu.Lock()
		if len(b.items) > 0 {
			items := b.items
			b.items = nil
			b.mu.Unlock()
			return items, true
		}
		if b.done {
			b.mu.Unlock()
			return nil, false
		}
		b.mu.Unlock()
		<-b.signal
	}
}

func (b *mailbox) close() {
	b.mu.Lock()
	b.done = true
	b.mu.Unlock()
	select {
	case b.signal <- struct{}{}:
	default:
	}
}

// onAgents is the agents broadcast listener (called under the agents lock).
func (m *Manager) onAgents(service string, data any) {
	if service != "agents.event" {
		return
	}
	ev, ok := data.(agents.Event)
	if !ok {
		return
	}
	switch ev.Kind {
	case agents.KindUser, agents.KindText, agents.KindPermissionRequest, agents.KindPermissionResolved,
		agents.KindError, agents.KindDone, agents.KindStatus:
	default:
		return
	}
	if _, ok := m.scopes.get(ev.Session); !ok {
		return // not a task session
	}
	m.inbox.put(ev)
}

func (m *Manager) consume() {
	for {
		evs, ok := m.inbox.take()
		if !ok {
			return
		}
		for _, ev := range evs {
			m.handle(ev)
		}
	}
}

// effects are side effects decided under the lock and run after it.
type effects []func()

func (e *effects) add(f func()) { *e = append(*e, f) }

func (e effects) run() {
	for _, f := range e {
		f()
	}
}

// handle advances a run's state machine on one agent event.
func (m *Manager) handle(ev agents.Event) {
	var fx effects
	m.mu.Lock()
	select {
	case <-m.closed: // shutting down: agent exits must not fail the runs
		m.mu.Unlock()
		return
	default:
	}
	ref, ok := m.bySession[ev.Session]
	t := m.tasks[ref.task]
	if !ok || t == nil || ref.idx >= len(t.Runs) || t.Runs[ref.idx].SessionID != ev.Session {
		m.mu.Unlock()
		return
	}
	r := t.Runs[ref.idx]
	live := activeStatus(r.Status) && r.Status != StatusVerifying
	changed := false
	switch ev.Kind {
	case agents.KindUser:
		r.turnText = ""
	case agents.KindText:
		r.turnText += ev.Text
	case agents.KindPermissionRequest:
		if live {
			r.Pending = append(r.Pending, ev.ID)
			r.Status = StatusWaiting
			changed = true
			if m.settings.notifyKind("permission") {
				fx.add(m.permissionNotice(t, r, ev))
			}
		}
	case agents.KindPermissionResolved:
		if i := indexOf(r.Pending, ev.ID); i >= 0 {
			r.Pending = append(r.Pending[:i], r.Pending[i+1:]...)
			if len(r.Pending) == 0 && r.Status == StatusWaiting {
				r.Status = workingStatus(r)
			}
			changed = true
		}
	case agents.KindError:
		if live {
			if hit, at := detectLimit(ev.Message, m.opt.Now()); hit {
				r.limitHit = true
				if !at.IsZero() {
					r.resetHint = at.UnixMilli()
				}
			} else {
				r.Error = oneLine(ev.Message, 600)
			}
		}
	case agents.KindDone:
		// Usage's top-level figures can be the agent's running totals
		// (Claude, Codex): only the turn's share adds up.
		if ev.Usage != nil && ev.Usage.Turn != nil {
			tu := ev.Usage.Turn
			c := Cost{InputTokens: tu.InputTokens, OutputTokens: tu.OutputTokens}
			if tu.CostUSD != nil {
				c.CostUSD = *tu.CostUSD
			}
			r.Cost.add(c)
			changed = true
		}
		if live {
			m.turnDoneLocked(t, r, &fx)
			changed = true
		}
	case agents.KindStatus:
		if ev.Status == agents.StatusExited && live {
			if r.limitHit {
				m.toLimitLocked(r)
			} else {
				m.failLocked(r, firstNonEmpty(r.Error, "the agent exited"))
			}
			r.Pending = []string{}
			changed = true
			fx.add(m.pump)
		}
	}
	if changed {
		m.changedLocked(t)
		m.noticeForTaskLocked(t, &fx)
	}
	m.mu.Unlock()
	fx.run()
}

func workingStatus(r *Run) string {
	if r.Phase == phasePlan {
		return StatusPlanning
	}
	return StatusRunning
}

// turnDoneLocked: the agent finished a turn.
func (m *Manager) turnDoneLocked(t *Task, r *Run, fx *effects) {
	text := strings.TrimSpace(r.turnText)
	switch {
	case r.limitHit:
		m.toLimitLocked(r)
		fx.add(m.pump)
	case r.Error != "" && text == "":
		m.failLocked(r, r.Error)
		fx.add(m.pump)
	case r.Phase == phasePlan:
		t.PlanText = text
		t.Plan = ParsePlan(text)
		r.Status = StatusAwaitingPlan
		m.scopes.set(r.SessionID, sessionScope{worktree: r.Worktree, inPlace: t.InPlace, planning: true})
		fx.add(m.pump)
	default:
		if text != "" {
			r.Summary, r.CommitMessage = parseCommit(text)
		}
		r.Error = ""
		r.Status = StatusVerifying
		tid, idx := t.ID, r.Index
		fx.add(func() { go m.verify(tid, idx) })
	}
	r.turnText = ""
}

func (m *Manager) failLocked(r *Run, msg string) {
	r.Status = StatusFailed
	r.Error = msg
	r.FinishedAt = m.now()
}

// toLimitLocked parks a run until its agent's limit resets.
func (m *Manager) toLimitLocked(r *Run) {
	at := r.resetHint
	switch {
	case at == 0: // unknown reset time
		at = m.opt.Now().Add(time.Duration(m.settings.withDefaults().LimitBackoff) * time.Second).UnixMilli()
	case at <= m.now(): // already reset (second resolution): retry shortly
		at = m.now() + 1000
	}
	r.Status = StatusWaitingLimit
	r.ResetsAt = at
	r.limitHit = false
	r.resetHint = 0
	r.Error = ""
}

func indexOf(list []string, s string) int {
	for i, v := range list {
		if v == s {
			return i
		}
	}
	return -1
}
