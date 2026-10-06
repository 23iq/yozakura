package routines

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// Step result statuses.
const (
	StatusOK      = "ok"
	StatusFailed  = "failed"
	StatusSkipped = "skipped"
)

// maxDepth bounds routines running routines.
const maxDepth = 3

// Executor performs the side effects of a run; tests fake it.
type Executor struct {
	// Exec runs argv (an action resolved by ActionArgv) and returns its
	// output.
	Exec func(ctx context.Context, argv []string) (string, error)
	// Tool calls a built-in MCP tool; isError reports a tool-level failure.
	Tool func(ctx context.Context, name string, args map[string]any) (text string, isError bool, err error)
	// Lookup finds a routine by id or name (nested routine actions).
	Lookup func(ref string) (Routine, bool)
	// Sleep waits d or until ctx ends (nil: a timer).
	Sleep func(ctx context.Context, d time.Duration) error
	Now   func() time.Time
}

// StepResult reports one step.
type StepResult struct {
	Index  int    `json:"index"`
	Kind   string `json:"kind"`
	Label  string `json:"label"`
	Status string `json:"status"`
	Output string `json:"output,omitempty"`
	Error  string `json:"error,omitempty"`
	Ms     int64  `json:"ms"`
}

// Report is the result of a run.
type Report struct {
	ID    string       `json:"id"`
	Name  string       `json:"name"`
	OK    bool         `json:"ok"`
	Steps []StepResult `json:"steps"`
	Ms    int64        `json:"ms"`
}

// StepLabel describes a step for reports and UIs ("Open Launcher",
// "tool dnd_set", "wait 2s").
func StepLabel(s Step) string {
	switch s.Kind {
	case KindAction:
		if s.Action == RoutineAction {
			return "Run routine " + argString(s.Args, "routine")
		}
		return ActionLabel(s.Action)
	case KindTool:
		return "Tool " + s.Tool
	case KindDelay:
		return "Wait " + (time.Duration(s.Ms) * time.Millisecond).String()
	}
	return s.Kind
}

func argString(args map[string]any, key string) string {
	if v, ok := args[key]; ok {
		return strings.TrimSpace(fmt.Sprint(v))
	}
	return ""
}

func (e Executor) now() time.Time {
	if e.Now != nil {
		return e.Now()
	}
	return time.Now()
}

func (e Executor) sleep(ctx context.Context, d time.Duration) error {
	if e.Sleep != nil {
		return e.Sleep(ctx, d)
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Run executes r step by step. A failed step stops the run (the rest is
// reported as skipped) unless r.ContinueOnError.
func (e Executor) Run(ctx context.Context, r Routine) Report {
	return e.run(ctx, r, 0)
}

func (e Executor) run(ctx context.Context, r Routine, depth int) Report {
	start := e.now()
	rep := Report{ID: r.ID, Name: r.Name, OK: true, Steps: make([]StepResult, 0, len(r.Steps))}
	stopped := false
	for i, s := range r.Steps {
		res := StepResult{Index: i, Kind: s.Kind, Label: StepLabel(s)}
		if stopped || ctx.Err() != nil {
			res.Status = StatusSkipped
			rep.Steps = append(rep.Steps, res)
			continue
		}
		t0 := e.now()
		out, err := e.step(ctx, s, depth)
		res.Ms = e.now().Sub(t0).Milliseconds()
		res.Output = truncate(out, 2000)
		if err != nil {
			res.Status, res.Error = StatusFailed, err.Error()
			rep.OK = false
			stopped = !r.ContinueOnError
		} else {
			res.Status = StatusOK
		}
		rep.Steps = append(rep.Steps, res)
	}
	if ctx.Err() != nil {
		rep.OK = false
	}
	rep.Ms = e.now().Sub(start).Milliseconds()
	return rep
}

func (e Executor) step(ctx context.Context, s Step, depth int) (string, error) {
	switch s.Kind {
	case KindDelay:
		return "", e.sleep(ctx, time.Duration(s.Ms)*time.Millisecond)
	case KindTool:
		if e.Tool == nil {
			return "", fmt.Errorf("tools are unavailable")
		}
		text, isErr, err := e.Tool(ctx, s.Tool, s.Args)
		if err != nil {
			return text, err
		}
		if isErr {
			return text, fmt.Errorf("%s", firstLine(text))
		}
		return text, nil
	case KindAction:
		if s.Action == RoutineAction {
			return e.nested(ctx, argString(s.Args, "routine"), depth)
		}
		argv, err := ActionArgv(s.Action, cloneArgs(s.Args))
		if err != nil {
			return "", err
		}
		if e.Exec == nil {
			return "", fmt.Errorf("cannot run commands")
		}
		return e.Exec(ctx, argv)
	}
	return "", fmt.Errorf("unknown step kind %q", s.Kind)
}

func (e Executor) nested(ctx context.Context, ref string, depth int) (string, error) {
	if depth+1 >= maxDepth {
		return "", fmt.Errorf("routines nest at most %d deep", maxDepth)
	}
	if e.Lookup == nil {
		return "", fmt.Errorf("no routine %q", ref)
	}
	sub, ok := e.Lookup(ref)
	if !ok {
		return "", fmt.Errorf("no routine %q", ref)
	}
	rep := e.run(ctx, sub, depth+1)
	done := 0
	for _, st := range rep.Steps {
		if st.Status == StatusOK {
			done++
		}
	}
	out := fmt.Sprintf("%s: %d/%d steps", sub.Name, done, len(rep.Steps))
	if !rep.OK {
		return out, fmt.Errorf("routine %q failed", sub.Name)
	}
	return out, nil
}

func cloneArgs(m map[string]any) map[string]any {
	out := make(map[string]any, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		s = s[:i]
	}
	if s == "" {
		return "the tool reported an error"
	}
	return truncate(s, 300)
}

func truncate(s string, n int) string {
	r := []rune(strings.TrimSpace(s))
	if len(r) <= n {
		return string(r)
	}
	return string(r[:n]) + "…"
}
