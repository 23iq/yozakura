package yozakura

import (
	"context"
	"encoding/json"
	"errors"
	"strings"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/svc/tasks"
)

// Task tools let an assistant delegate coding work to CLI agents through
// the daemon's tasks service (one git worktree per run, verify loop,
// review in the AI bar's Code space). Accepting stays with the user.

func taskTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("task_create", "Create coding task",
			`Hand a coding task to a CLI coding agent (Claude Code, Codex, OpenCode) working in a git project. The agent works in its own git worktree (branch yoz/<id>) unless inPlace is true; when it finishes, the project's check command runs and failures go back to it; then the task waits for the user's review in the AI bar (Code space), where the user accepts (one squashed commit) or discards it. "dir" is the project directory (absolute). "agents": several agents run the same task in parallel (best-of-N), the user picks one. "mode": "plan" makes the agent propose a numbered plan first that the user approves. "template": a task template id (review, tests, fix-check, explain, refactor, or the user's own); "prompt" then fills its {{input}}. Returns the task (id, status, runs). Use task_status to follow it.`,
			`{"type":"object","properties":{"dir":{"type":"string","description":"Project directory (absolute path)."},"prompt":{"type":"string","description":"What the agent should do."},"title":{"type":"string"},"agent":{"type":"string","enum":["claude","codex","opencode"],"description":"Default claude."},"agents":{"type":"array","items":{"type":"string"},"maxItems":4,"description":"Best-of-N: one run per agent."},"mode":{"type":"string","enum":["run","plan"]},"inPlace":{"type":"boolean","description":"Work in the checkout itself instead of a worktree."},"template":{"type":"string"},"model":{"type":"string"},"effort":{"type":"string"}},"required":["dir"],"additionalProperties":false}`,
			toolOpts{}, d.taskCreate),
		define("task_list", "List coding tasks",
			`List the coding tasks (newest first): id, title, project, status (queued, planning, awaiting_plan, running, waiting = needs the user, waiting_limit, verifying, review, accepted, discarded, failed, cancelled) and the agent of each run. "dir" filters by project; "active": true hides finished tasks.`,
			`{"type":"object","properties":{"dir":{"type":"string"},"active":{"type":"boolean"}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.taskList),
		define("task_status", "Coding task status",
			`Details of one coding task: status, plan, and per run the agent, branch, check results (pass/fail with the output tail), changed files, the agent's summary and proposed commit message, errors and cost.`,
			`{"type":"object","properties":{"id":{"type":"string"}},"required":["id"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.taskStatus),
	}
}

func (d Deps) taskCreate(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var p tasks.CreateParams
	if err := decode(args, &p); err != nil {
		return nil, err
	}
	if strings.TrimSpace(p.Prompt) == "" && p.Template == "" {
		return nil, errors.New("prompt is required")
	}
	if p.Agent == "" && len(p.Agents) == 0 {
		p.Agent = "claude"
	}
	raw, err := d.call("tasks.create", p)
	if err != nil {
		return nil, err
	}
	var t tasks.Task
	if err := json.Unmarshal(raw, &t); err != nil {
		return nil, err
	}
	return mcp.JSONResult(taskOut(t, true)), nil
}

func (d Deps) taskList(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Dir    string `json:"dir"`
		Active bool   `json:"active"`
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	raw, err := d.call("tasks.list", map[string]any{"dir": a.Dir})
	if err != nil {
		return nil, err
	}
	var list []tasks.Task
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, err
	}
	out := []map[string]any{}
	for _, t := range list {
		switch t.Status {
		case tasks.StatusAccepted, tasks.StatusDiscarded, tasks.StatusFailed, tasks.StatusCancelled:
			if a.Active {
				continue
			}
		}
		out = append(out, taskOut(t, false))
	}
	return mcp.JSONResult(map[string]any{"tasks": out}), nil
}

func (d Deps) taskStatus(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		ID string `json:"id"`
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	raw, err := d.call("tasks.get", map[string]any{"id": a.ID})
	if err != nil {
		return nil, err
	}
	var t tasks.Task
	if err := json.Unmarshal(raw, &t); err != nil {
		return nil, err
	}
	return mcp.JSONResult(taskOut(t, true)), nil
}

// taskOut is the agent-facing view of a task (no internal session ids).
func taskOut(t tasks.Task, detail bool) map[string]any {
	runs := []map[string]any{}
	for _, r := range t.Runs {
		ro := map[string]any{"index": r.Index, "agent": r.Agent, "status": r.Status}
		if r.Branch != "" {
			ro["branch"] = r.Branch
		}
		if detail {
			ro["worktree"] = r.Worktree
			ro["summary"] = r.Summary
			ro["commitMessage"] = r.CommitMessage
			ro["checks"] = r.Checks
			ro["changes"] = r.Changes
			ro["costUsd"] = r.Cost.CostUSD
			if r.Error != "" {
				ro["error"] = r.Error
			}
		}
		runs = append(runs, ro)
	}
	out := map[string]any{"id": t.ID, "title": t.Title, "project": t.ProjectDir, "status": t.Status, "mode": t.Mode, "runs": runs}
	if detail {
		out["plan"] = t.Plan
		out["inPlace"] = t.InPlace
		if t.Error != "" {
			out["error"] = t.Error
		}
		if t.Status == tasks.StatusReview || t.Status == tasks.StatusAwaitingPlan {
			out["next"] = "the user reviews this task in the AI bar (Code space)"
		}
	}
	return out
}
