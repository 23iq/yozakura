package tasks

import (
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"strings"

	"yozakura/backend/pkg/svc/agents"
)

// CreateParams are tasks.create.
type CreateParams struct {
	Dir      string            `json:"dir"`
	Title    string            `json:"title"`
	Prompt   string            `json:"prompt"`
	Agent    string            `json:"agent"`
	Agents   []string          `json:"agents"` // best-of-N: one run per entry
	Model    string            `json:"model"`
	Effort   string            `json:"effort"`
	Mode     string            `json:"mode"` // plan | run (default run)
	InPlace  bool              `json:"inPlace"`
	Template string            `json:"template"`
	Vars     map[string]string `json:"vars"` // template placeholders (input, selection, file, ...)
	Fallback string            `json:"fallbackAgent"`
}

const maxRuns = 4

// Create registers a task, prepares one worktree per run and queues it.
func (m *Manager) Create(p CreateParams) (Task, error) {
	dir, err := projectRoot(p.Dir, true)
	if err != nil {
		return Task{}, err
	}
	list := p.Agents
	if len(list) == 0 && p.Agent != "" {
		list = []string{p.Agent}
	}
	if len(list) == 0 {
		return Task{}, errors.New("agent is required")
	}
	if len(list) > maxRuns {
		return Task{}, fmt.Errorf("at most %d agents per task", maxRuns)
	}
	for _, a := range list {
		if agents.Lookup(a) == nil {
			return Task{}, errors.New("unknown agent: " + a)
		}
	}
	if p.Fallback != "" && agents.Lookup(p.Fallback) == nil {
		return Task{}, errors.New("unknown fallback agent: " + p.Fallback)
	}
	prompt := strings.TrimSpace(p.Prompt)
	if p.Template != "" {
		tpl, err := GetTemplate(m.opt.Templates, dir, p.Template)
		if err != nil {
			return Task{}, err
		}
		vars := map[string]string{}
		for k, v := range p.Vars {
			vars[k] = v
		}
		if _, ok := vars["input"]; !ok {
			vars["input"] = prompt
		}
		prompt = m.RenderIn(dir, tpl.Body, vars)
		if p.Mode == "" {
			p.Mode = tpl.Mode
		}
		if p.Title == "" {
			p.Title = strings.TrimSuffix(tpl.Name+": "+strings.TrimSpace(p.Prompt), ": ")
		}
	}
	if prompt == "" {
		return Task{}, errors.New("prompt is required")
	}
	switch p.Mode {
	case "":
		p.Mode = ModeRun
	case ModeRun, ModePlan:
	default:
		return Task{}, errors.New("mode must be plan or run")
	}
	inPlace := p.InPlace
	isGit := isGitRepo(dir)
	if !isGit && !inPlace {
		return Task{}, errors.New("not a git repository: " + dir + " (run the task in place instead)")
	}
	if inPlace && len(list) > 1 {
		return Task{}, errors.New("several agents need worktrees: in-place tasks take one agent")
	}
	now := m.opt.Now()
	t := &Task{ID: newTaskID(now), ProjectDir: dir, Title: oneLine(firstNonEmpty(p.Title, prompt), 80), Prompt: prompt,
		Mode: p.Mode, InPlace: inPlace, Status: StatusQueued, Plan: []string{}, Runs: []*Run{}, AcceptedRun: -1,
		Template: p.Template, Fallback: p.Fallback, CreatedAt: now.UnixMilli(), UpdatedAt: now.UnixMilli()}
	if isGit {
		head, err := git(dir, "rev-parse", "HEAD")
		if err != nil {
			return Task{}, errors.New("the repository has no commit yet")
		}
		t.BaseCommit, t.BaseBranch = head, currentBranch(dir)
	}
	for i, a := range list {
		r := &Run{Index: i, Agent: a, Model: p.Model, Effort: p.Effort, Status: StatusQueued, Phase: phaseWork,
			SessionIDs: []string{}, Checks: []CheckRun{}, Pending: []string{}, Worktree: dir}
		if len(list) > 1 {
			r.Model, r.Effort = "", "" // models are agent specific
		}
		if t.Mode == ModePlan {
			r.Phase = phasePlan
			if i > 0 {
				r.Status, r.Phase = StatusAwaitingPlan, phaseWork
			}
		}
		if !inPlace {
			suffix := ""
			if len(list) > 1 {
				suffix = fmt.Sprintf("-%d", i+1)
			}
			r.Branch = branchPrefix + t.ID + suffix
			r.Worktree = filepath.Join(m.opt.WorktreeRoot, projectSlug(dir), t.ID+suffix)
			if err := addWorktree(dir, r.Worktree, r.Branch, t.BaseCommit); err != nil {
				for _, prev := range t.Runs {
					_ = removeWorktree(dir, prev.Worktree, prev.Branch)
				}
				return Task{}, err
			}
		}
		t.Runs = append(t.Runs, r)
	}
	m.mu.Lock()
	m.tasks[t.ID] = t
	m.changedLocked(t)
	out := t.clone()
	m.mu.Unlock()
	m.pump()
	return out, nil
}

var slugChars = regexp.MustCompile(`[^A-Za-z0-9._-]+`)

// projectSlug names a project's worktree folder: <basename>-<hash>.
func projectSlug(dir string) string {
	sum := sha1.Sum([]byte(dir))
	base := slugChars.ReplaceAllString(filepath.Base(dir), "-")
	return strings.Trim(base, "-.") + "-" + hex.EncodeToString(sum[:3])
}

// RenderIn renders a template body for a project.
func (m *Manager) RenderIn(dir, body string, vars map[string]string) string {
	return Render(body, vars, dir, func() string {
		m.mu.Lock()
		p := m.projectLocked(dir)
		m.mu.Unlock()
		return effectiveCheck(p)
	})
}
