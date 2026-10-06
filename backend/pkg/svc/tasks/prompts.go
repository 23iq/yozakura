package tasks

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// The agent is asked to end its work with a summary and a commit message
// in a fenced block tagged `commit`; parseCommit picks it up for accept.
const workRules = "\n\n---\nRules for this task:\n" +
	"- Work only inside the current directory (a dedicated git worktree). Do not push, publish or contact remote services.\n" +
	"- Do not create commits; the user reviews and commits your changes.\n" +
	"- When you are done, reply with a short summary of what you changed and a proposed commit message " +
	"(first line under 72 characters) in a fenced code block tagged `commit`."

const inPlaceRules = "\n\n---\nRules for this task:\n" +
	"- Do not push, publish or contact remote services. Do not create commits.\n" +
	"- When you are done, reply with a short summary of what you changed and a proposed commit message " +
	"(first line under 72 characters) in a fenced code block tagged `commit`."

const planRules = "\n\n---\nPLAN MODE: do not change any file and do not run commands that modify anything; " +
	"only read the code you need. Reply with a concise numbered plan (1., 2., ...), one step per line, " +
	"that you will carry out once the user approves it."

func planPrompt(task string) string { return strings.TrimSpace(task) + planRules }

func workPrompt(task string, plan []string, inPlace bool) string {
	p := strings.TrimSpace(task)
	if len(plan) > 0 {
		p += "\n\nFollow this plan approved by the user:\n" + formatPlan(plan)
	}
	if inPlace {
		return p + inPlaceRules
	}
	return p + workRules
}

// approvedPlanMessage continues the planning session with the edited plan.
func approvedPlanMessage(plan []string, inPlace bool) string {
	msg := "The user approved this plan (possibly edited). Implement it now:\n" + formatPlan(plan)
	if inPlace {
		return msg + inPlaceRules
	}
	return msg + workRules
}

func fixPrompt(cr CheckRun, attempt, max int) string {
	what := fmt.Sprintf("exited with status %d", cr.ExitCode)
	if cr.Status == CheckTimeout {
		what = "timed out"
	}
	return fmt.Sprintf("The project check `%s` %s (fix attempt %d of %d). Fix the problems, then reply with the summary "+
		"and the `commit` block again.\n\nLast output:\n```\n%s\n```", cr.Command, what, attempt, max, strings.TrimSpace(cr.OutputTail))
}

func limitResumePrompt() string {
	return "The usage limit has reset. Continue the task where you left off."
}

func fallbackPrompt(task string, plan []string, inPlace bool, prev string) string {
	return workPrompt(task, plan, inPlace) + "\n\nNote: another agent (" + prev + ") started this task and hit its usage " +
		"limit; its partial work may already be in this directory. Inspect it and finish the task."
}

func formatPlan(plan []string) string {
	var b strings.Builder
	for i, s := range plan {
		fmt.Fprintf(&b, "%d. %s\n", i+1, strings.TrimSpace(s))
	}
	return b.String()
}

var (
	numbered = regexp.MustCompile(`^\s*(?:\*\*)?(\d+)[.)](?:\*\*)?\s+(.+)$`)
	bulleted = regexp.MustCompile(`^\s*[-*•]\s+(.+)$`)
)

// ParsePlan extracts plan steps from the agent's answer: numbered lines
// (with indented continuation lines folded in), else bullet lines, else
// the non-empty paragraphs.
func ParsePlan(text string) []string {
	lines := strings.Split(text, "\n")
	for _, re := range []*regexp.Regexp{numbered, bulleted} {
		var steps []string
		for _, l := range lines {
			if m := re.FindStringSubmatch(l); m != nil {
				steps = append(steps, strings.TrimSpace(m[len(m)-1]))
			} else if len(steps) > 0 && strings.TrimSpace(l) != "" && (strings.HasPrefix(l, "  ") || strings.HasPrefix(l, "\t")) {
				steps[len(steps)-1] += " " + strings.TrimSpace(l)
			}
		}
		if len(steps) > 0 {
			return steps
		}
	}
	var out []string
	for _, p := range strings.Split(text, "\n\n") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, strings.Join(strings.Fields(p), " "))
		}
	}
	return out
}

var commitBlock = regexp.MustCompile("(?s)```commit[^\n]*\n(.*?)```")

// parseCommit splits the agent's final answer into summary and commit
// message (the `commit` fenced block).
func parseCommit(text string) (summary, message string) {
	m := commitBlock.FindStringSubmatchIndex(text)
	if m == nil {
		return strings.TrimSpace(text), ""
	}
	message = strings.TrimSpace(text[m[2]:m[3]])
	summary = strings.TrimSpace(text[:m[0]] + text[m[1]:])
	return summary, message
}

// defaultCommitMessage is used when the agent proposed none.
func defaultCommitMessage(t *Task, r *Run) string {
	title := oneLine(firstNonEmpty(t.Title, t.Prompt), 68)
	body := strings.TrimSpace(r.Summary)
	if body == "" {
		return title
	}
	return title + "\n\n" + body
}

func oneLine(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > n {
		return string(r[:n-1]) + "…"
	}
	return s
}

var (
	limitWords = regexp.MustCompile(`(?i)(usage limit|rate limit|rate_limit|limit reached|hit your limit|too many requests|` +
		`\b429\b|quota exceeded|overloaded)`)
	limitEpoch = regexp.MustCompile(`\|(\d{10})\b`)
	limitIn    = regexp.MustCompile(`(?i)\b(?:in|after)\s+(?:(\d+)\s*(?:hours?|hrs?|h))?\s*(?:(\d+)\s*(?:minutes?|mins?|m)\b)?\s*(?:(\d+)\s*(?:seconds?|secs?|s)\b)?`)
	limitAt    = regexp.MustCompile(`(?i)(?:resets?|again|available)\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?`)
)

// detectLimit reports whether an agent error is a usage/rate limit and,
// when the message says, when it resets.
func detectLimit(msg string, now time.Time) (bool, time.Time) {
	if !limitWords.MatchString(msg) {
		return false, time.Time{}
	}
	if m := limitEpoch.FindStringSubmatch(msg); m != nil {
		sec, _ := strconv.ParseInt(m[1], 10, 64)
		return true, time.Unix(sec, 0)
	}
	for _, m := range limitIn.FindAllStringSubmatch(msg, -1) {
		if m[1] == "" && m[2] == "" && m[3] == "" {
			continue
		}
		h, _ := strconv.Atoi(m[1])
		mi, _ := strconv.Atoi(m[2])
		s, _ := strconv.Atoi(m[3])
		return true, now.Add(time.Duration(h)*time.Hour + time.Duration(mi)*time.Minute + time.Duration(s)*time.Second)
	}
	if m := limitAt.FindStringSubmatch(msg); m != nil {
		h, _ := strconv.Atoi(m[1])
		mi, _ := strconv.Atoi(m[2])
		switch strings.ToLower(m[3]) {
		case "pm":
			if h < 12 {
				h += 12
			}
		case "am":
			if h == 12 {
				h = 0
			}
		}
		if h < 24 && mi < 60 {
			t := time.Date(now.Year(), now.Month(), now.Day(), h, mi, 0, 0, now.Location())
			if !t.After(now) {
				t = t.Add(24 * time.Hour)
			}
			return true, t
		}
	}
	return true, time.Time{}
}
