package tasks

import (
	"time"
)

// verify runs the project check in a run's worktree after the agent
// finished; a failure goes back to the same session until the project's
// maxAttempts is used up, then (or on success) the run is ready for review.
func (m *Manager) verify(taskID string, idx int) {
	m.mu.Lock()
	t := m.tasks[taskID]
	if t == nil || idx >= len(t.Runs) || t.Runs[idx].Status != StatusVerifying {
		m.mu.Unlock()
		return
	}
	r := t.Runs[idx]
	p := m.projectLocked(t.ProjectDir)
	dir := r.Worktree
	m.mu.Unlock()

	cr := runCheck(dir, effectiveCheck(p), time.Duration(p.CheckTimeout)*time.Second, m.opt.Now)

	m.mu.Lock()
	if t.Runs[idx].Status != StatusVerifying { // cancelled or discarded meanwhile
		m.mu.Unlock()
		return
	}
	r.Checks = append(r.Checks, cr)
	var send string
	if (cr.Status == CheckFail || cr.Status == CheckTimeout) && r.Attempts < p.MaxAttempts && r.SessionID != "" {
		r.Attempts++
		r.Phase = phaseFix
		r.Status = StatusRunning
		send = fixPrompt(cr, r.Attempts, p.MaxAttempts)
	}
	session := r.SessionID
	m.changedLocked(t)
	m.mu.Unlock()
	if send != "" {
		if err := m.opt.Agents.Send(session, send, nil); err != nil {
			m.mu.Lock()
			m.failLocked(r, err.Error())
			m.changedLocked(t)
			m.mu.Unlock()
			m.pump()
		}
		return
	}
	m.toReview(taskID, idx)
}

// toReview snapshots the run's changes and marks it ready for review.
func (m *Manager) toReview(taskID string, idx int) {
	m.mu.Lock()
	t := m.tasks[taskID]
	if t == nil || idx >= len(t.Runs) {
		m.mu.Unlock()
		return
	}
	r := t.Runs[idx]
	inPlace, dir, branch, base, title := t.InPlace, r.Worktree, r.Branch, t.BaseCommit, t.Title
	m.mu.Unlock()

	var stats *ChangeStats
	var snapErr error
	switch {
	case inPlace && base != "":
		stats, _ = changeStats(dir, base, "")
	case !inPlace:
		if _, snapErr = snapshot(dir, "wip: "+oneLine(title, 60)); snapErr == nil {
			stats, _ = changeStats(dir, base, branch)
		}
	}

	var fx effects
	m.mu.Lock()
	if r.Status != StatusVerifying {
		m.mu.Unlock()
		return
	}
	if snapErr != nil {
		m.failLocked(r, "could not record the changes: "+snapErr.Error())
	} else {
		r.Changes = stats
		r.Status = StatusReview
		r.FinishedAt = m.now()
	}
	session := r.SessionID
	m.changedLocked(t)
	m.noticeForTaskLocked(t, &fx)
	m.mu.Unlock()
	fx.run()
	if session != "" {
		// Free the idle agent process; a follow-up resumes the session.
		_ = m.opt.Agents.CloseSession(session)
	}
	m.pump()
}
