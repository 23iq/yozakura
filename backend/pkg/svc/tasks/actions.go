package tasks

import (
	"errors"
	"strings"
)

// UpdatePlan replaces the plan steps of a task awaiting approval.
func (m *Manager) UpdatePlan(id string, steps []string) (Task, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	t, err := m.taskLocked(id)
	if err != nil {
		return Task{}, err
	}
	if t.Status != StatusAwaitingPlan {
		return Task{}, errors.New("the task is not waiting for plan approval")
	}
	t.Plan = cleanSteps(steps)
	m.changedLocked(t)
	return t.clone(), nil
}

func cleanSteps(steps []string) []string {
	out := []string{}
	for _, s := range steps {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

// Run approves the plan (optionally replacing its steps) and starts the
// work: the planning session continues with the plan, the other runs of a
// best-of-N task start fresh with it.
func (m *Manager) Run(id string, steps []string) (Task, error) {
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	if t.Status != StatusAwaitingPlan {
		m.mu.Unlock()
		return Task{}, errors.New("the task is not waiting for plan approval")
	}
	if steps != nil {
		t.Plan = cleanSteps(steps)
	}
	if len(t.Plan) == 0 {
		m.mu.Unlock()
		return Task{}, errors.New("the plan is empty")
	}
	for _, r := range t.Runs {
		if r.Status != StatusAwaitingPlan {
			continue
		}
		r.Status, r.Phase = StatusQueued, phaseWork
		if r.SessionID != "" {
			r.followup = approvedPlanMessage(t.Plan, t.InPlace)
			m.scopes.set(r.SessionID, sessionScope{worktree: r.Worktree, inPlace: t.InPlace})
		}
	}
	m.changedLocked(t)
	out := t.clone()
	m.mu.Unlock()
	m.pump()
	return out, nil
}

// Followup sends the user's comment ("request changes") to a run and
// starts another turn; on a task awaiting plan approval it revises the plan.
func (m *Manager) Followup(id string, idx int, text string) (Task, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return Task{}, errors.New("text is required")
	}
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	r, err := t.run(idx)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	switch {
	case t.Status == StatusAccepted || r.Status == StatusDiscarded:
		m.mu.Unlock()
		return Task{}, errors.New("the task is closed")
	case activeStatus(r.Status) || r.Status == StatusQueued:
		m.mu.Unlock()
		return Task{}, errors.New("the agent is still working; wait or cancel first")
	case r.Status == StatusAwaitingPlan && r.SessionID != "":
		r.Phase = phasePlan
		r.followup = text + "\n\nReply with the revised numbered plan only; do not change files yet."
	case r.Status == StatusAwaitingPlan:
		m.mu.Unlock()
		return Task{}, errors.New("approve the plan first")
	case r.SessionID == "":
		r.Phase = phaseWork
		r.followup = workPrompt(t.Prompt+"\n\n"+text, t.Plan, t.InPlace)
	default:
		r.Phase = phaseWork
		r.followup = text + "\n\nWhen you are done, reply with the summary and the `commit` block again."
	}
	r.Status = StatusQueued
	r.Attempts = 0
	r.Error = ""
	m.changedLocked(t)
	out := t.clone()
	m.mu.Unlock()
	m.pump()
	return out, nil
}

// Cancel stops every unfinished run of a task (worktrees are kept: the
// task can be resumed with a follow-up or discarded).
func (m *Manager) Cancel(id string) (Task, error) {
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	var stop []string
	for _, r := range t.Runs {
		if activeStatus(r.Status) || r.Status == StatusQueued || r.Status == StatusWaitingLimit ||
			r.Status == StatusAwaitingPlan {
			r.Status = StatusCancelled
			r.Pending = []string{}
			r.FinishedAt = m.now()
			if r.SessionID != "" {
				stop = append(stop, r.SessionID)
			}
		}
	}
	m.changedLocked(t)
	out := t.clone()
	m.mu.Unlock()
	for _, s := range stop {
		_ = m.opt.Agents.Cancel(s)
		_ = m.opt.Agents.CloseSession(s)
	}
	m.pump()
	return out, nil
}

// Discard removes the worktree and branch of one run (idx >= 0) or of
// every run (idx < 0). An in-place task's changes stay in the checkout.
func (m *Manager) Discard(id string, idx int) (Task, error) {
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	if t.Status == StatusAccepted {
		m.mu.Unlock()
		return Task{}, errors.New("the task was accepted")
	}
	var runs []*Run
	if idx >= 0 {
		r, err := t.run(idx)
		if err != nil {
			m.mu.Unlock()
			return Task{}, err
		}
		runs = []*Run{r}
	} else {
		runs = t.Runs
	}
	type job struct{ session, worktree, branch string }
	var jobs []job
	for _, r := range runs {
		if r.Status == StatusDiscarded {
			continue
		}
		j := job{session: r.SessionID}
		if !t.InPlace {
			j.worktree, j.branch = r.Worktree, r.Branch
		}
		jobs = append(jobs, j)
		r.Status = StatusDiscarded
		r.Pending = []string{}
		m.forgetSessionLocked(r)
	}
	all := true
	for _, r := range t.Runs {
		all = all && r.Status == StatusDiscarded
	}
	if all {
		t.Status = StatusDiscarded
	}
	dir := t.ProjectDir
	m.changedLocked(t)
	out := t.clone()
	m.mu.Unlock()
	var errs []error
	for _, j := range jobs {
		if j.session != "" {
			_ = m.opt.Agents.Cancel(j.session)
			_ = m.opt.Agents.CloseSession(j.session)
		}
		if j.worktree != "" {
			errs = append(errs, removeWorktree(dir, j.worktree, j.branch))
		}
	}
	m.pump()
	return out, errors.Join(errs...)
}

// AcceptParams are tasks.accept.
type AcceptParams struct {
	ID      string `json:"id"`
	Run     int    `json:"run"`
	Message string `json:"message"` // commit message; default: the agent's proposal
}

// Accept integrates a reviewed run into the project's current branch as
// one commit, then discards the other runs and every task worktree.
func (m *Manager) Accept(p AcceptParams) (Task, error) {
	m.mu.Lock()
	t, err := m.taskLocked(p.ID)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	r, err := t.run(p.Run)
	if err != nil {
		m.mu.Unlock()
		return Task{}, err
	}
	if r.Status != StatusReview {
		m.mu.Unlock()
		return Task{}, errors.New("the run is not ready for review")
	}
	msg := strings.TrimSpace(firstNonEmpty(p.Message, r.CommitMessage))
	if msg == "" {
		msg = defaultCommitMessage(t, r)
	}
	dir, inPlace, wt, branch, title := t.ProjectDir, t.InPlace, r.Worktree, r.Branch, t.Title
	mode := m.projectLocked(dir).MergeMode
	m.mu.Unlock()

	var sha string
	if inPlace {
		if isGitRepo(dir) {
			sha, err = commitInPlace(dir, msg)
		}
	} else {
		if _, err = snapshot(wt, "wip: "+oneLine(title, 60)); err == nil {
			sha, err = integrate(dir, branch, msg, mode)
		}
	}
	if err != nil {
		return Task{}, err
	}

	m.mu.Lock()
	t.Status = StatusAccepted
	t.AcceptedRun = p.Run
	t.CommitSHA = sha
	type job struct{ session, worktree, branch string }
	var jobs []job
	for _, x := range t.Runs {
		j := job{session: x.SessionID}
		if !inPlace {
			j.worktree, j.branch = x.Worktree, x.Branch
		}
		jobs = append(jobs, j)
		x.Status = StatusDiscarded
		if x == r {
			x.Status = StatusAccepted
		}
		m.forgetSessionLocked(x)
	}
	m.changedLocked(t)
	out := t.clone()
	m.mu.Unlock()
	for _, j := range jobs {
		if j.session != "" {
			_ = m.opt.Agents.CloseSession(j.session)
		}
		if j.worktree != "" {
			_ = removeWorktree(dir, j.worktree, j.branch)
		}
	}
	m.pump()
	return out, nil
}

// Delete forgets a finished task (accepted, discarded, failed, cancelled);
// an unfinished one is discarded first.
func (m *Manager) Delete(id string) error {
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return err
	}
	needDiscard := t.Status != StatusAccepted && t.Status != StatusDiscarded
	m.mu.Unlock()
	if needDiscard {
		if _, err := m.Discard(id, -1); err != nil {
			return err
		}
	}
	m.mu.Lock()
	delete(m.tasks, id)
	delete(m.notified, id)
	m.st.deleteTask(id)
	m.broadcast("tasks.removed", map[string]any{"id": id})
	m.publishActivityLocked()
	m.mu.Unlock()
	return nil
}
