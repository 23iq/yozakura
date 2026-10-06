// Package tasks runs AI-first coding tasks: a prompt handed to one or more
// CLI agents (best-of-N), each in its own git worktree, with an optional
// plan step, a verify loop on the project's check command, a review and an
// accept (squash into the current branch) or discard.
package tasks

// Task status values (Task.Status).
const (
	StatusQueued       = "queued"
	StatusPlanning     = "planning"
	StatusAwaitingPlan = "awaiting_plan"
	StatusRunning      = "running"
	StatusWaiting      = "waiting"       // a run needs the user (permission)
	StatusWaitingLimit = "waiting_limit" // subscription/rate limit, retried later
	StatusVerifying    = "verifying"
	StatusReview       = "review"
	StatusAccepted     = "accepted"
	StatusDiscarded    = "discarded"
	StatusFailed       = "failed"
	StatusCancelled    = "cancelled"
)

// Task modes.
const (
	ModePlan = "plan"
	ModeRun  = "run"
)

// Run phases: what the agent of a run is doing in its current turn.
const (
	phasePlan = "plan"
	phaseWork = "work"
	phaseFix  = "fix"
)

// Check result states.
const (
	CheckPass    = "pass"
	CheckFail    = "fail"
	CheckSkipped = "skipped"
	CheckTimeout = "timeout"
)

// Task is one unit of work on a project; Runs holds one entry per agent
// (best-of-N), each with its own worktree, branch and agent session.
type Task struct {
	ID          string   `json:"id"`
	ProjectDir  string   `json:"projectDir"`
	Title       string   `json:"title"`
	Prompt      string   `json:"prompt"`
	Mode        string   `json:"mode"` // plan | run
	InPlace     bool     `json:"inPlace"`
	Status      string   `json:"status"`
	Plan        []string `json:"plan"`
	PlanText    string   `json:"planText,omitempty"`
	BaseCommit  string   `json:"baseCommit,omitempty"`
	BaseBranch  string   `json:"baseBranch,omitempty"`
	Runs        []*Run   `json:"runs"`
	AcceptedRun int      `json:"acceptedRun"` // index, -1 when none
	CommitSHA   string   `json:"commitSha,omitempty"`
	Error       string   `json:"error,omitempty"`
	Template    string   `json:"template,omitempty"`
	Fallback    string   `json:"fallbackAgent,omitempty"`
	CreatedAt   int64    `json:"createdAt"`
	UpdatedAt   int64    `json:"updatedAt"`
	StartedAt   int64    `json:"startedAt,omitempty"`
	FinishedAt  int64    `json:"finishedAt,omitempty"`
	Cost        Cost     `json:"cost"`
}

// Run is one agent working on a task.
type Run struct {
	Index         int          `json:"index"`
	Agent         string       `json:"agent"`
	Model         string       `json:"model,omitempty"`
	Effort        string       `json:"effort,omitempty"`
	Status        string       `json:"status"`
	Phase         string       `json:"phase,omitempty"`
	Worktree      string       `json:"worktree"` // path; the project dir when in place
	Branch        string       `json:"branch,omitempty"`
	SessionID     string       `json:"sessionId,omitempty"`
	SessionIDs    []string     `json:"sessionIds"` // every session used (fallbacks too)
	Attempts      int          `json:"attempts"`   // fix attempts after failed checks
	Checks        []CheckRun   `json:"checks"`
	Summary       string       `json:"summary,omitempty"`
	CommitMessage string       `json:"commitMessage,omitempty"`
	Changes       *ChangeStats `json:"changes,omitempty"`
	Error         string       `json:"error,omitempty"`
	ResetsAt      int64        `json:"resetsAt,omitempty"` // ms; waiting_limit retry time
	Pending       []string     `json:"pending"`            // open permission request ids
	Cost          Cost         `json:"cost"`
	StartedAt     int64        `json:"startedAt,omitempty"`
	FinishedAt    int64        `json:"finishedAt,omitempty"`

	turnText  string // assistant text of the current turn (not persisted)
	limitHit  bool
	resetHint int64
	followup  string // message to send when a queued run resumes
}

// CheckRun is one execution of the project check command.
type CheckRun struct {
	Command    string `json:"command"`
	Status     string `json:"status"` // pass | fail | timeout | skipped
	ExitCode   int    `json:"exitCode"`
	DurationMs int64  `json:"durationMs"`
	OutputTail string `json:"outputTail"`
	At         int64  `json:"at"`
}

// ChangeStats summarize a run's diff against the task base.
type ChangeStats struct {
	Files      int      `json:"files"`
	Insertions int      `json:"insertions"`
	Deletions  int      `json:"deletions"`
	Paths      []string `json:"paths"`
}

// Cost accumulates agent usage.
type Cost struct {
	InputTokens  int64   `json:"inputTokens"`
	OutputTokens int64   `json:"outputTokens"`
	CostUSD      float64 `json:"costUsd"`
}

func (c *Cost) add(o Cost) {
	c.InputTokens += o.InputTokens
	c.OutputTokens += o.OutputTokens
	c.CostUSD += o.CostUSD
}

// Project is the per-project task configuration (tasks.project.set).
type Project struct {
	Dir string `json:"dir"`
	// CheckCommand runs in the worktree after the agent finishes (through
	// `sh -c`, it is the user's own command line). nil: auto-detected;
	// "": no check.
	CheckCommand *string `json:"checkCommand"`
	MaxAttempts  int     `json:"maxAttempts"`  // fix attempts after a failed check (default 2)
	MergeMode    string  `json:"mergeMode"`    // squash (default) | merge
	CheckTimeout int     `json:"checkTimeout"` // seconds (default 600)
}

// ProjectView is tasks.project.get: the stored config plus what the
// backend derived (effective check command, detection suggestion).
type ProjectView struct {
	Project
	EffectiveCheck string `json:"effectiveCheck"`
	SuggestedCheck string `json:"suggestedCheck"`
	IsGit          bool   `json:"isGit"`
	Instructions   string `json:"instructions"` // AGENTS.md / CLAUDE.md when present
}

// Settings are global task settings (tasks.configure, persisted).
type Settings struct {
	MaxParallel   int    `json:"maxParallel"`   // concurrently active runs (default 2)
	FallbackAgent string `json:"fallbackAgent"` // used when an agent hits its limit
	LimitBackoff  int    `json:"limitBackoff"`  // seconds when the reset time is unknown (default 1800)
	Notify        *bool  `json:"notify"`        // desktop notifications (default on)
}

func (s Settings) withDefaults() Settings {
	if s.MaxParallel <= 0 {
		s.MaxParallel = 2
	}
	if s.LimitBackoff <= 0 {
		s.LimitBackoff = 1800
	}
	return s
}

func (s Settings) notifyOn() bool { return s.Notify == nil || *s.Notify }

func (p Project) withDefaults() Project {
	if p.MaxAttempts <= 0 {
		p.MaxAttempts = 2
	}
	if p.MergeMode == "" {
		p.MergeMode = "squash"
	}
	if p.CheckTimeout <= 0 {
		p.CheckTimeout = 600
	}
	return p
}

// active run statuses hold a queue slot.
func activeStatus(st string) bool {
	switch st {
	case StatusPlanning, StatusRunning, StatusWaiting, StatusVerifying:
		return true
	}
	return false
}

func terminalStatus(st string) bool {
	switch st {
	case StatusAccepted, StatusDiscarded, StatusFailed, StatusCancelled:
		return true
	}
	return false
}
