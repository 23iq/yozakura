package tasks

import (
	"errors"

	"yozakura/backend/pkg/svc/agents"
)

// Open asks the shell to show a task (notification "Open" action).
func (m *Manager) Open(id string, run int) error {
	m.mu.Lock()
	if _, err := m.taskLocked(id); err != nil {
		m.mu.Unlock()
		return err
	}
	m.broadcast("tasks.open", map[string]any{"id": id, "run": run})
	m.mu.Unlock()
	if m.opt.OpenUI != nil {
		m.opt.OpenUI()
	}
	return nil
}

// DebugInfo is tasks.debug: the agent session's raw view plus the last
// check output of the run.
type DebugInfo struct {
	agents.DebugInfo
	Sessions  []string  `json:"sessions"`
	LastCheck *CheckRun `json:"lastCheck,omitempty"`
}

// Debug returns the debug view of a run's agent session.
func (m *Manager) Debug(id string, idx, lines int) (DebugInfo, error) {
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return DebugInfo{}, err
	}
	r, err := t.run(idx)
	if err != nil {
		m.mu.Unlock()
		return DebugInfo{}, err
	}
	out := DebugInfo{Sessions: append([]string{}, r.SessionIDs...)}
	if n := len(r.Checks); n > 0 {
		c := r.Checks[n-1]
		out.LastCheck = &c
	}
	sid := r.SessionID
	if sid == "" && len(r.SessionIDs) > 0 {
		sid = r.SessionIDs[len(r.SessionIDs)-1]
	}
	m.mu.Unlock()
	if sid == "" {
		out.LogTail, out.Argv = []string{}, []string{}
		return out, nil
	}
	info, err := m.opt.Agents.Debug(sid, lines)
	if err != nil {
		return DebugInfo{}, err
	}
	out.DebugInfo = info
	return out, nil
}

// Diff returns the unified diff of a run against the task base (the
// worktree's uncommitted changes included).
func (m *Manager) Diff(id string, idx int) (string, error) {
	m.mu.Lock()
	t, err := m.taskLocked(id)
	if err != nil {
		m.mu.Unlock()
		return "", err
	}
	r, err := t.run(idx)
	if err != nil {
		m.mu.Unlock()
		return "", err
	}
	dir, base, inPlace := r.Worktree, t.BaseCommit, t.InPlace
	m.mu.Unlock()
	if base == "" {
		return "", errors.New("the project is not a git repository")
	}
	if !inPlace { // untracked files of a task worktree show up as additions
		if _, err := git(dir, "add", "-A", "--intent-to-add"); err != nil {
			return "", err
		}
	}
	return git(dir, "diff", base)
}
