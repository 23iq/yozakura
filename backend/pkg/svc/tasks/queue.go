package tasks

import (
	"sort"
	"time"

	"yozakura/backend/pkg/svc/agents"
)

// launch is a decided run start, executed outside the lock.
type launch struct {
	task, title, agent, model, effort, cwd string
	idx                                    int
	session                                string // "" = create a new session
	text                                   string
	verify                                 bool
	scope                                  sessionScope
}

// pump moves limit-parked runs whose reset time passed back to the queue
// and starts queued runs while slots are free.
func (m *Manager) pump() {
	m.mu.Lock()
	select {
	case <-m.closed:
		m.mu.Unlock()
		return
	default:
	}
	now := m.now()
	var next int64
	var touched []*Task
	active := 0
	type cand struct {
		t *Task
		r *Run
	}
	var queued []cand
	for _, t := range m.tasks {
		dirty := false
		for _, r := range t.Runs {
			if r.Status == StatusWaitingLimit {
				if r.ResetsAt <= now {
					m.resumeAfterLimitLocked(t, r)
					dirty = true
				} else if next == 0 || r.ResetsAt < next {
					next = r.ResetsAt
				}
			}
			if activeStatus(r.Status) {
				active++
			}
			if r.Status == StatusQueued {
				queued = append(queued, cand{t, r})
			}
		}
		if dirty {
			touched = append(touched, t)
		}
	}
	sort.Slice(queued, func(i, j int) bool {
		if queued[i].t.CreatedAt != queued[j].t.CreatedAt {
			return queued[i].t.CreatedAt < queued[j].t.CreatedAt
		}
		return queued[i].r.Index < queued[j].r.Index
	})
	var starts []launch
	slots := m.settings.withDefaults().MaxParallel - active
	for _, c := range queued {
		if slots <= 0 {
			break
		}
		starts = append(starts, m.claimLocked(c.t, c.r))
		if !contains(touched, c.t) {
			touched = append(touched, c.t)
		}
		slots--
	}
	for _, t := range touched {
		m.changedLocked(t)
	}
	m.armLimitTimerLocked(next)
	m.mu.Unlock()
	for _, l := range starts {
		go m.start(l)
	}
}

func contains(list []*Task, t *Task) bool {
	for _, x := range list {
		if x == t {
			return true
		}
	}
	return false
}

func (m *Manager) armLimitTimerLocked(next int64) {
	if m.limitT != nil {
		m.limitT.Stop()
		m.limitT = nil
	}
	if next == 0 {
		return
	}
	wait := time.Duration(next-m.now())*time.Millisecond + 50*time.Millisecond
	m.limitT = time.AfterFunc(max(wait, 0), m.pump)
}

// resumeAfterLimitLocked queues a parked run again: in its own session,
// or with the fallback agent in a fresh session.
func (m *Manager) resumeAfterLimitLocked(t *Task, r *Run) {
	r.Status = StatusQueued
	r.ResetsAt = 0
	fb := firstNonEmpty(t.Fallback, m.settings.FallbackAgent)
	if fb != "" && fb != r.Agent && agents.Lookup(fb) != nil {
		prev := r.Agent
		r.Agent, r.Model, r.Effort = fb, "", ""
		m.forgetSessionLocked(r)
		r.followup = fallbackPrompt(t.Prompt, t.Plan, t.InPlace, prev)
		return
	}
	r.followup = limitResumePrompt()
}

func (m *Manager) forgetSessionLocked(r *Run) {
	if r.SessionID != "" {
		delete(m.bySession, r.SessionID)
		m.scopes.drop(r.SessionID)
	}
	r.SessionID = ""
}

// claimLocked marks a queued run as started and returns what to launch.
func (m *Manager) claimLocked(t *Task, r *Run) launch {
	l := launch{task: t.ID, idx: r.Index, title: t.Title, agent: r.Agent, model: r.Model, effort: r.Effort,
		cwd: r.Worktree, session: r.SessionID}
	planning := t.Mode == ModePlan && r.Phase == phasePlan
	switch {
	case r.followup == verifyMarker:
		l.verify = true
		r.Status = StatusVerifying
	case r.SessionID == "" && r.followup != "":
		l.text = r.followup // fallback agent: full prompt
	case r.SessionID == "" && planning:
		l.text = planPrompt(t.Prompt)
	case r.SessionID == "":
		l.text = workPrompt(t.Prompt, t.Plan, t.InPlace)
	default:
		l.text = r.followup
	}
	r.followup = ""
	if !l.verify {
		r.Status = StatusRunning
		if planning {
			r.Status = StatusPlanning
		}
	}
	r.Error = ""
	r.turnText = ""
	if r.StartedAt == 0 {
		r.StartedAt = m.now()
	}
	if t.StartedAt == 0 {
		t.StartedAt = m.now()
	}
	l.scope = sessionScope{worktree: r.Worktree, inPlace: t.InPlace, planning: planning}
	return l
}

// start creates the agent session when needed and sends the turn.
func (m *Manager) start(l launch) {
	if l.verify {
		m.verify(l.task, l.idx)
		return
	}
	id := l.session
	if id == "" {
		no := false
		meta, err := m.opt.Agents.Create(agents.CreateParams{Agent: l.agent, Cwd: l.cwd, Title: l.title,
			Model: l.model, Effort: l.effort, Yolo: &no, Mode: agents.ModeAgent})
		if err != nil {
			m.startFailed(l, err)
			return
		}
		id = meta.ID
		m.mu.Lock()
		t := m.tasks[l.task]
		if t == nil || l.idx >= len(t.Runs) || terminalStatus(t.Runs[l.idx].Status) {
			m.mu.Unlock()
			_ = m.opt.Agents.CloseSession(id)
			return
		}
		r := t.Runs[l.idx]
		r.SessionID = id
		r.SessionIDs = append(r.SessionIDs, id)
		m.bySession[id] = runRef{l.task, l.idx}
		m.changedLocked(t)
		m.mu.Unlock()
	}
	m.scopes.set(id, l.scope)
	if err := m.opt.Agents.Send(id, l.text, nil); err != nil {
		m.startFailed(l, err)
	}
}

func (m *Manager) startFailed(l launch, err error) {
	m.mu.Lock()
	t := m.tasks[l.task]
	if t != nil && l.idx < len(t.Runs) && activeStatus(t.Runs[l.idx].Status) {
		m.failLocked(t.Runs[l.idx], err.Error())
		m.changedLocked(t)
		var fx effects
		m.noticeForTaskLocked(t, &fx)
		m.mu.Unlock()
		fx.run()
		m.pump()
		return
	}
	m.mu.Unlock()
}
