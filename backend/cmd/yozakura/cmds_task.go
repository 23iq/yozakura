package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"text/tabwriter"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/svc/tasks"
)

const taskUsage = `Usage: {bin} task new <prompt> [--agent claude[,codex]] [--dir DIR] [--plan] [--in-place]
                [--model M] [--effort E] [--template NAME] [--fallback AGENT]
       {bin} task list [--dir DIR] [--json]       Tasks, newest first
       {bin} task show <id> [--json]              Status, runs, checks, plan
       {bin} task run <id>                        Approve the plan and start the work
       {bin} task followup <id> <text> [--run N]  Request changes (or revise a plan)
       {bin} task accept <id> [--run N] [-m MSG]  Squash the run into the current branch
       {bin} task discard <id> [--run N]          Remove worktree(s) and branch(es)
       {bin} task cancel|delete <id>
       {bin} task diff <id> [--run N]             Unified diff of a run
       {bin} task debug <id> [--run N] [--lines N]
       {bin} task project [DIR] [--check CMD | --auto] [--max-attempts N] [--merge squash|merge]
       {bin} task templates [DIR]                 Bundled, global and project templates
       {bin} task git [DIR]                       Branch, ahead/behind, changed files

Each run works in its own git worktree under ~/.local/share/{bin}/worktrees
(branch yoz/<id>); --in-place works in the checkout itself. When the agent
finishes, the project check runs (--check, else auto-detected) and failures
go back to the agent; then the task waits for review.
`

// taskCaller calls the daemon's tasks service (tests fake it).
type taskCaller func(method string, params any) (json.RawMessage, error)

func defaultTaskCaller(method string, params any) (json.RawMessage, error) {
	if !isAlive() {
		return nil, fmt.Errorf("%s is not running", brand.DisplayName)
	}
	return newClient().Call("tasks."+method, params)
}

func runTask(args []string, out, errOut io.Writer) int {
	return runTaskWith(defaultTaskCaller, args, out, errOut)
}

func runTaskWith(call taskCaller, args []string, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		fmt.Fprint(errOut, branded(taskUsage))
		return 2
	}
	c := parseCLI(args[1:], []string{"json", "plan", "in-place", "auto"},
		[]string{"agent", "dir", "model", "effort", "template", "fallback", "run", "m", "message", "lines", "check",
			"max-attempts", "merge"})
	cwd, _ := os.Getwd()
	dir := cwd
	if d, ok := c.value("dir"); ok {
		dir = d
	}
	runIdx := 0
	if v, ok := c.value("run"); ok {
		runIdx, _ = strconv.Atoi(v)
	}
	id := ""
	if len(c.pos) > 0 {
		id = c.pos[0]
	}
	var res json.RawMessage
	var err error
	switch sub := args[0]; sub {
	case "new", "create", "add":
		p := map[string]any{"dir": dir, "prompt": strings.Join(c.pos, " "), "inPlace": c.has("in-place")}
		agentsList := strings.Split(valueOr(c, "agent", "claude"), ",")
		p["agents"] = agentsList
		if c.has("plan") {
			p["mode"] = tasks.ModePlan
		}
		for _, k := range []string{"model", "effort", "template"} {
			if v, ok := c.value(k); ok {
				p[k] = v
			}
		}
		if v, ok := c.value("fallback"); ok {
			p["fallbackAgent"] = v
		}
		if res, err = call("create", p); err == nil {
			return printTask(res, c.has("json"), out)
		}
	case "list", "ls":
		p := map[string]any{}
		if v, ok := c.value("dir"); ok {
			p["dir"] = v
		}
		if res, err = call("list", p); err == nil {
			return printTaskList(res, c.has("json"), out)
		}
	case "show", "status", "get":
		if res, err = call("get", map[string]any{"id": id}); err == nil {
			return printTask(res, c.has("json"), out)
		}
	case "run", "approve":
		if res, err = call("run", map[string]any{"id": id}); err == nil {
			return printTask(res, false, out)
		}
	case "followup", "changes":
		text := strings.Join(c.pos[min(1, len(c.pos)):], " ")
		if res, err = call("followup", map[string]any{"id": id, "run": runIdx, "text": text}); err == nil {
			return printTask(res, false, out)
		}
	case "accept":
		msg := valueOr(c, "m", valueOr(c, "message", ""))
		if res, err = call("accept", map[string]any{"id": id, "run": runIdx, "message": msg}); err == nil {
			return printTask(res, false, out)
		}
	case "discard":
		p := map[string]any{"id": id}
		if _, ok := c.value("run"); ok {
			p["run"] = runIdx
		}
		if res, err = call("discard", p); err == nil {
			return printTask(res, false, out)
		}
	case "cancel":
		if res, err = call("cancel", map[string]any{"id": id}); err == nil {
			return printTask(res, false, out)
		}
	case "delete", "rm":
		if _, err = call("delete", map[string]any{"id": id}); err == nil {
			fmt.Fprintf(out, "deleted %s\n", id)
			return 0
		}
	case "diff":
		var d struct{ Diff string }
		if res, err = call("diff", map[string]any{"id": id, "run": runIdx}); err == nil {
			_ = json.Unmarshal(res, &d)
			fmt.Fprint(out, d.Diff)
			return 0
		}
	case "debug":
		lines, _ := strconv.Atoi(valueOr(c, "lines", "40"))
		if res, err = call("debug", map[string]any{"id": id, "run": runIdx, "lines": lines}); err == nil {
			return printTaskJSON(res, out)
		}
	case "project":
		return runTaskProject(call, c, firstPos(c, cwd), out, errOut)
	case "templates", "template":
		if res, err = call("templates.list", map[string]any{"dir": firstPos(c, cwd)}); err == nil {
			return printTemplates(res, c.has("json"), out)
		}
	case "git":
		if res, err = call("git", map[string]any{"dir": firstPos(c, cwd)}); err == nil {
			return printTaskJSON(res, out)
		}
	case "activity":
		if res, err = call("activity", nil); err == nil {
			return printTaskJSON(res, out)
		}
	default:
		fmt.Fprintf(errOut, "Error: unknown task command %q\n", sub)
		fmt.Fprint(errOut, branded(taskUsage))
		return 2
	}
	return timerFail(errOut, err)
}

func valueOr(c cliArgs, name, def string) string {
	if v, ok := c.value(name); ok {
		return v
	}
	return def
}

func firstPos(c cliArgs, def string) string {
	if len(c.pos) > 0 {
		return c.pos[0]
	}
	return def
}

func runTaskProject(call taskCaller, c cliArgs, dir string, out, errOut io.Writer) int {
	p := map[string]any{"dir": dir}
	set := false
	if v, ok := c.value("check"); ok {
		p["checkCommand"], set = v, true
	}
	if c.has("auto") {
		p["resetCheck"], set = true, true
	}
	if v, ok := c.value("max-attempts"); ok {
		n, err := strconv.Atoi(v)
		if err != nil {
			fmt.Fprintln(errOut, "Error: --max-attempts takes a number")
			return 2
		}
		p["maxAttempts"], set = n, true
	}
	if v, ok := c.value("merge"); ok {
		p["mergeMode"], set = v, true
	}
	method := "project.get"
	if set {
		method = "project.set"
	}
	res, err := call(method, p)
	if err != nil {
		return timerFail(errOut, err)
	}
	if c.has("json") {
		return printTaskJSON(res, out)
	}
	var v tasks.ProjectView
	_ = json.Unmarshal(res, &v)
	check := v.EffectiveCheck
	if check == "" {
		check = "(none)"
	}
	if v.CheckCommand == nil {
		check += " (auto)"
	}
	fmt.Fprintf(out, "project       %s\ncheck         %s\nmax attempts  %d\nmerge         %s\ninstructions  %s\n",
		v.Dir, check, v.MaxAttempts, v.MergeMode, firstNonBlank(v.Instructions, "(none)"))
	return 0
}

func firstNonBlank(s, def string) string {
	if s == "" {
		return def
	}
	return s
}

func printTaskJSON(res json.RawMessage, out io.Writer) int {
	var v any
	_ = json.Unmarshal(res, &v)
	data, _ := json.MarshalIndent(v, "", "  ")
	fmt.Fprintln(out, string(data))
	return 0
}

func printTaskList(res json.RawMessage, asJSON bool, out io.Writer) int {
	if asJSON {
		return printTaskJSON(res, out)
	}
	var list []tasks.Task
	_ = json.Unmarshal(res, &list)
	if len(list) == 0 {
		fmt.Fprintln(out, "no tasks")
		return 0
	}
	w := tabwriter.NewWriter(out, 0, 2, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tSTATUS\tAGENTS\tAGE\tTITLE")
	for _, t := range list {
		age := time.Since(time.UnixMilli(t.CreatedAt)).Round(time.Minute)
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", t.ID, t.Status, runAgents(t), age, t.Title)
	}
	_ = w.Flush()
	return 0
}

func runAgents(t tasks.Task) string {
	names := make([]string, 0, len(t.Runs))
	for _, r := range t.Runs {
		names = append(names, r.Agent)
	}
	return strings.Join(names, ",")
}

func printTask(res json.RawMessage, asJSON bool, out io.Writer) int {
	if asJSON {
		return printTaskJSON(res, out)
	}
	var t tasks.Task
	_ = json.Unmarshal(res, &t)
	fmt.Fprintf(out, "%s  %s  %s\n", t.ID, t.Status, t.Title)
	if t.Error != "" {
		fmt.Fprintf(out, "  error: %s\n", t.Error)
	}
	for i, s := range t.Plan {
		fmt.Fprintf(out, "  plan %d. %s\n", i+1, s)
	}
	for _, r := range t.Runs {
		fmt.Fprintf(out, "  run %d  %-8s %-13s %s\n", r.Index, r.Agent, r.Status, firstNonBlank(r.Branch, "(in place)"))
		for _, c := range r.Checks {
			fmt.Fprintf(out, "         check %q: %s\n", c.Command, c.Status)
		}
		if r.Changes != nil {
			fmt.Fprintf(out, "         %d files, +%d -%d\n", r.Changes.Files, r.Changes.Insertions, r.Changes.Deletions)
		}
		if r.Error != "" {
			fmt.Fprintf(out, "         error: %s\n", r.Error)
		}
	}
	return 0
}

func printTemplates(res json.RawMessage, asJSON bool, out io.Writer) int {
	if asJSON {
		return printTaskJSON(res, out)
	}
	var list []tasks.Template
	_ = json.Unmarshal(res, &list)
	w := tabwriter.NewWriter(out, 0, 2, 2, ' ', 0)
	for _, t := range list {
		fmt.Fprintf(w, "/%s\t%s\t%s\n", t.ID, t.Source, t.Description)
	}
	_ = w.Flush()
	return 0
}
