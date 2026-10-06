package tasks

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"sync"
	"time"

	"yozakura/backend/pkg/svc/agents"
	"yozakura/backend/pkg/svc/notify"
)

// Agents is the part of the agents.Manager the task engine drives.
type Agents interface {
	Create(p agents.CreateParams) (agents.SessionMeta, error)
	Send(id, text string, images []string) error
	Cancel(id string) error
	CloseSession(id string) error
	Debug(id string, lines int) (agents.DebugInfo, error)
	AddListener(fn func(service string, data any))
	SetPermissionHook(h agents.PermissionHook)
}

// Options configure New; Dir and Agents are required.
type Options struct {
	Dir          string // task state (~/.local/share/<app>/tasks)
	WorktreeRoot string // ~/.local/share/<app>/worktrees
	Templates    TemplateDirs
	Agents       Agents
	Notify       func(notify.SendParams) // nil: no desktop notifications
	OpenUI       func()                  // shows the AI bar's Code space (tasks.open)
	Now          func() time.Time
}

// branchPrefix names task branches: yoz/<task id>[-n].
const branchPrefix = "yoz/"

type runRef struct {
	task string
	idx  int
}

// Manager owns every task. Lock order: never call Agents with mu held
// (the agents manager calls our hook and listener under its own lock).
type Manager struct {
	mu        sync.Mutex
	opt       Options
	st        store
	tasks     map[string]*Task
	projects  map[string]Project
	settings  Settings
	bySession map[string]runRef
	scopes    scopes
	inbox     *mailbox
	limitT    *time.Timer
	broadcast func(kind string, data any)
	activity  string            // last broadcast activity (JSON) to skip repeats
	notified  map[string]string // task id -> status last notified
	closed    chan struct{}
}

// New loads persisted tasks and attaches to the agents manager.
func New(o Options) *Manager {
	if o.Now == nil {
		o.Now = time.Now
	}
	m := &Manager{opt: o, st: store{dir: o.Dir}, tasks: map[string]*Task{}, bySession: map[string]runRef{},
		inbox: newMailbox(), notified: map[string]string{}, broadcast: func(string, any) {}, closed: make(chan struct{})}
	m.projects = m.st.loadProjects()
	m.settings = m.st.loadSettings()
	for _, t := range m.st.loadTasks() {
		m.tasks[t.ID] = t
		m.restoreLocked(t)
	}
	o.Agents.SetPermissionHook(m.scopes.decide)
	o.Agents.AddListener(m.onAgents)
	go m.consume()
	return m
}

// Start runs queued work (call once the daemon is up).
func (m *Manager) Start() { m.pump() }

// Close stops the event loop and timers (agent sessions belong to agents).
func (m *Manager) Close() {
	m.mu.Lock()
	defer m.mu.Unlock()
	select {
	case <-m.closed:
		return
	default:
	}
	close(m.closed)
	m.inbox.close()
	if m.limitT != nil {
		m.limitT.Stop()
	}
}

// SetBroadcast sets the subscription fan-out (kind, data).
func (m *Manager) SetBroadcast(fn func(kind string, data any)) {
	m.mu.Lock()
	m.broadcast = fn
	m.mu.Unlock()
}

// restoreLocked re-indexes a loaded task; runs whose process died with
// the daemon resume in their session when a slot is free.
func (m *Manager) restoreLocked(t *Task) {
	for _, r := range t.Runs {
		if r.SessionID != "" {
			m.bySession[r.SessionID] = runRef{t.ID, r.Index}
			m.scopes.set(r.SessionID, sessionScope{worktree: r.Worktree, inPlace: t.InPlace, planning: r.Phase == phasePlan})
		}
		r.Pending = []string{}
		switch r.Status {
		case StatusPlanning, StatusRunning, StatusWaiting:
			r.Status = StatusQueued
			if r.SessionID != "" {
				r.followup = "The session was interrupted (the shell restarted). Continue the task where you left off."
				if r.Phase == phasePlan {
					r.followup = "The session was interrupted. Reply with the numbered plan again."
				}
			}
		case StatusVerifying:
			r.Status = StatusQueued
			r.followup = verifyMarker
		}
	}
	m.recompute(t)
}

// verifyMarker as a queued run's followup re-runs the check instead of
// talking to the agent.
const verifyMarker = "\x00verify"

func newTaskID(now time.Time) string {
	b := make([]byte, 2)
	_, _ = rand.Read(b)
	return "k" + strconv.FormatInt(now.UnixMilli(), 36) + hex.EncodeToString(b)
}

func (m *Manager) now() int64 { return m.opt.Now().UnixMilli() }

// task returns the task (mu held).
func (m *Manager) taskLocked(id string) (*Task, error) {
	t := m.tasks[id]
	if t == nil {
		return nil, errors.New("unknown task: " + id)
	}
	return t, nil
}

func (t *Task) run(idx int) (*Run, error) {
	if idx < 0 || idx >= len(t.Runs) {
		return nil, errors.New("unknown run " + strconv.Itoa(idx) + " of task " + t.ID)
	}
	return t.Runs[idx], nil
}

// clone is a deep copy safe to hand out after the lock is released.
func (t *Task) clone() Task {
	data, _ := json.Marshal(t)
	var c Task
	_ = json.Unmarshal(data, &c)
	return c
}

// Get returns one task.
func (m *Manager) Get(id string) (Task, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	t, err := m.taskLocked(id)
	if err != nil {
		return Task{}, err
	}
	return t.clone(), nil
}

// List returns tasks, newest first; dir filters by project ("" = all).
func (m *Manager) List(dir string) []Task {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Task{}
	for _, t := range m.tasks {
		if dir == "" || t.ProjectDir == dir {
			out = append(out, t.clone())
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].CreatedAt != out[j].CreatedAt {
			return out[i].CreatedAt > out[j].CreatedAt
		}
		return out[i].ID > out[j].ID
	})
	return out
}

// changedLocked persists a task and publishes it plus the activity.
func (m *Manager) changedLocked(t *Task) {
	m.recompute(t)
	t.UpdatedAt = m.now()
	select {
	case <-m.closed: // shutting down: keep the last saved state
	default:
		m.st.saveTask(t)
	}
	m.broadcast("tasks.updated", t.clone())
	m.publishActivityLocked()
}

// recompute derives the task status and cost from its runs.
func (m *Manager) recompute(t *Task) {
	var cost Cost
	for _, r := range t.Runs {
		cost.add(r.Cost)
	}
	t.Cost = cost
	if t.Status == StatusAccepted || t.Status == StatusDiscarded {
		return
	}
	has := map[string]bool{}
	for _, r := range t.Runs {
		has[r.Status] = true
	}
	// Queued before awaiting_plan: the other runs of a plan-mode task wait
	// for the plan while the planner is still queued.
	for _, st := range []string{StatusWaiting, StatusPlanning, StatusRunning, StatusVerifying, StatusQueued,
		StatusAwaitingPlan, StatusWaitingLimit, StatusReview, StatusFailed, StatusCancelled, StatusDiscarded} {
		if has[st] {
			t.Status = st
			break
		}
	}
	t.Error = ""
	if t.Status == StatusFailed {
		for _, r := range t.Runs {
			if r.Error != "" {
				t.Error = r.Error
				break
			}
		}
	}
	if terminalStatus(t.Status) || t.Status == StatusReview {
		if t.FinishedAt == 0 {
			t.FinishedAt = m.now()
		}
	} else {
		t.FinishedAt = 0
	}
}

// Settings returns the global task settings (defaults applied).
func (m *Manager) Settings() Settings {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.settings.withDefaults()
}

// Configure replaces the global settings and re-runs the queue.
func (m *Manager) Configure(s Settings) Settings {
	m.mu.Lock()
	m.settings = s
	m.st.saveSettings(s)
	m.mu.Unlock()
	m.pump()
	return s.withDefaults()
}

// projectLocked returns the project config with defaults.
func (m *Manager) projectLocked(dir string) Project {
	p := m.projects[dir]
	p.Dir = dir
	if p.MergeMode == "" {
		p.MergeMode = m.settings.MergeMode
	}
	return p.withDefaults()
}

// effectiveCheck is the check command used for dir.
func effectiveCheck(p Project) string {
	if p.CheckCommand != nil {
		return *p.CheckCommand
	}
	return DetectCheck(p.Dir)
}

// Project returns the project view for dir.
func (m *Manager) Project(dir string) (ProjectView, error) {
	dir, err := projectRoot(dir, true)
	if err != nil {
		return ProjectView{}, err
	}
	m.mu.Lock()
	p := m.projectLocked(dir)
	m.mu.Unlock()
	v := ProjectView{Project: p, SuggestedCheck: DetectCheck(dir), IsGit: isGitRepo(dir)}
	v.EffectiveCheck = effectiveCheck(p)
	for _, n := range []string{"AGENTS.md", "CLAUDE.md"} {
		if fileExists(filepath.Join(dir, n)) {
			v.Instructions = n
			break
		}
	}
	return v, nil
}

// SetProject stores a project's config (fields left nil are kept).
func (m *Manager) SetProject(p ProjectPatch) (ProjectView, error) {
	dir, err := projectRoot(p.Dir, true)
	if err != nil {
		return ProjectView{}, err
	}
	m.mu.Lock()
	cur := m.projects[dir]
	cur.Dir = dir
	if p.CheckCommand != nil {
		cur.CheckCommand = p.CheckCommand
	}
	if p.ResetCheck {
		cur.CheckCommand = nil
	}
	if p.MaxAttempts != nil {
		cur.MaxAttempts = max(*p.MaxAttempts, 0)
	}
	if p.MergeMode != nil {
		if *p.MergeMode != "squash" && *p.MergeMode != "merge" {
			m.mu.Unlock()
			return ProjectView{}, errors.New("mergeMode must be squash or merge")
		}
		cur.MergeMode = *p.MergeMode
	}
	if p.CheckTimeout != nil {
		cur.CheckTimeout = max(*p.CheckTimeout, 0)
	}
	m.projects[dir] = cur
	m.st.saveProjects(m.projects)
	m.mu.Unlock()
	return m.Project(dir)
}

// ProjectPatch is tasks.project.set.
type ProjectPatch struct {
	Dir          string  `json:"dir"`
	CheckCommand *string `json:"checkCommand"`
	ResetCheck   bool    `json:"resetCheck"` // back to auto-detection
	MaxAttempts  *int    `json:"maxAttempts"`
	MergeMode    *string `json:"mergeMode"`
	CheckTimeout *int    `json:"checkTimeout"`
}

// projectRoot resolves dir to an absolute path (its git top level when it
// is in a repository).
func projectRoot(dir string, mustExist bool) (string, error) {
	if dir == "" {
		return "", errors.New("dir is required")
	}
	abs, err := filepath.Abs(dir)
	if err != nil {
		return "", err
	}
	if st, err := os.Stat(abs); mustExist && (err != nil || !st.IsDir()) {
		return "", errors.New("not a directory: " + abs)
	}
	if root, err := repoRoot(abs); err == nil && root != "" {
		return root, nil
	}
	return abs, nil
}
