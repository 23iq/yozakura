package tasks

import (
	"encoding/json"
	"fmt"
	"time"

	"yozakura/backend/pkg/svc/agents"
	"yozakura/backend/pkg/svc/notify"
)

// Activity is the compact task summary for the notch (tasks.activity).
// Headline is a kind the UI translates: waiting | running | review |
// failed | limit | queued | idle; Agent names the agent concerned.
type Activity struct {
	Running  int            `json:"running"`
	Waiting  int            `json:"waiting"`
	Review   int            `json:"review"`
	Queued   int            `json:"queued"`
	Failed   int            `json:"failed"`
	Limited  int            `json:"limited"`
	Headline string         `json:"headline"`
	Agent    string         `json:"agent"`
	TaskID   string         `json:"taskId"`
	Items    []ActivityItem `json:"items"`
}

// ActivityItem is one unfinished task in the activity.
type ActivityItem struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	Agent     string `json:"agent"`
	StartedAt int64  `json:"startedAt"`
	ResetsAt  int64  `json:"resetsAt,omitempty"`
}

// Activity builds the current summary.
func (m *Manager) Activity() Activity {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.activityLocked()
}

func (m *Manager) activityLocked() Activity {
	a := Activity{Items: []ActivityItem{}, Headline: "idle"}
	var waitingT, runningT, reviewT *Task
	for _, t := range m.sortedLocked() {
		switch t.Status {
		case StatusWaiting, StatusAwaitingPlan:
			a.Waiting++
			waitingT = t
		case StatusPlanning, StatusRunning, StatusVerifying:
			a.Running++
			runningT = t
		case StatusReview:
			a.Review++
			reviewT = t
		case StatusQueued:
			a.Queued++
		case StatusWaitingLimit:
			a.Limited++
		case StatusFailed:
			a.Failed++
			continue
		default:
			continue
		}
		it := ActivityItem{ID: t.ID, Title: t.Title, Status: t.Status, StartedAt: t.StartedAt}
		if len(t.Runs) > 0 {
			it.Agent = agentLabel(t.Runs[0].Agent)
			it.ResetsAt = t.Runs[0].ResetsAt
		}
		a.Items = append(a.Items, it)
	}
	pick := func(kind string, t *Task) {
		a.Headline, a.TaskID = kind, t.ID
		if len(t.Runs) > 0 {
			a.Agent = agentLabel(t.Runs[0].Agent)
		}
	}
	switch {
	case waitingT != nil:
		pick("waiting", waitingT)
	case runningT != nil:
		pick("running", runningT)
	case reviewT != nil:
		pick("review", reviewT)
	case a.Limited > 0:
		a.Headline = "limit"
	case a.Queued > 0:
		a.Headline = "queued"
	}
	return a
}

func (m *Manager) sortedLocked() []*Task {
	out := make([]*Task, 0, len(m.tasks))
	for _, t := range m.tasks {
		out = append(out, t)
	}
	// Oldest first, so the newest task of a kind wins the headline.
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j].CreatedAt < out[j-1].CreatedAt; j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	return out
}

func (m *Manager) publishActivityLocked() {
	a := m.activityLocked()
	data, _ := json.Marshal(a)
	if string(data) == m.activity {
		return
	}
	m.activity = string(data)
	m.broadcast("tasks.activity", a)
}

func agentLabel(id string) string {
	if a := agents.Lookup(id); a != nil {
		return a.Label()
	}
	return id
}

func openAction(id string) notify.SendAction {
	return notify.SendAction{Identifier: "open", Text: "Open", Call: &notify.ActionCall{Method: "tasks.open",
		Params: map[string]any{"id": id}}}
}

func (m *Manager) send(p notify.SendParams) func() {
	n := m.opt.Notify
	return func() {
		if n != nil {
			n(p)
		}
	}
}

// permissionNotice asks for a permission from the notification itself.
func (m *Manager) permissionNotice(t *Task, r *Run, ev agents.Event) func() {
	respond := func(decision string) *notify.ActionCall {
		return &notify.ActionCall{Method: "agents.respond", Params: map[string]any{
			"session": r.SessionID, "request": ev.ID, "decision": decision}}
	}
	return m.send(notify.SendParams{
		Summary: agentLabel(r.Agent) + " is waiting", Body: oneLine(firstNonEmpty(ev.Title, ev.Tool), 160) + "\n" + t.Title,
		AppIcon: "dialog-question", Urgency: "critical", ReplaceKey: "task-perm-" + ev.ID,
		Actions: []notify.SendAction{
			{Identifier: "allow", Text: "Allow", Call: respond(agents.DecisionAllow)},
			{Identifier: "deny", Text: "Deny", Call: respond(agents.DecisionDeny)},
			openAction(t.ID),
		},
	})
}

// noticeForTaskLocked notifies once per task status the user must act on
// (plan ready, review, failed, waiting for a limit).
func (m *Manager) noticeForTaskLocked(t *Task, fx *effects) {
	if !m.settings.notifyOn() || m.opt.Notify == nil {
		return
	}
	key := "task-" + t.ID
	p := notify.SendParams{AppIcon: "dialog-information", ReplaceKey: key, Body: t.Title, Urgency: "normal"}
	kind := ""
	switch t.Status {
	case StatusAwaitingPlan:
		kind = "plan"
		p.Summary = "Plan ready"
		p.Actions = []notify.SendAction{{Identifier: "run", Text: "Run", Call: &notify.ActionCall{Method: "tasks.run",
			Params: map[string]any{"id": t.ID}}}, openAction(t.ID)}
	case StatusReview:
		kind = "review"
		p.Summary = "Ready for review"
		if c := lastCheck(t); c != "" {
			p.Body += "\nCheck: " + c
		}
		p.Actions = []notify.SendAction{openAction(t.ID)}
	case StatusFailed:
		kind = "failed"
		p.Summary, p.AppIcon, p.Urgency = "Task failed", "dialog-error", "critical"
		if t.Error != "" {
			p.Body += "\n" + oneLine(t.Error, 200)
		}
		p.Actions = []notify.SendAction{openAction(t.ID)}
	case StatusWaitingLimit:
		kind = "limit"
		p.Summary = "Waiting for the usage limit"
		for _, r := range t.Runs {
			if r.ResetsAt > 0 {
				p.Body += fmt.Sprintf("\nRetry at %s", time.UnixMilli(r.ResetsAt).Format("15:04"))
				break
			}
		}
		p.Actions = []notify.SendAction{openAction(t.ID)}
	default:
		delete(m.notified, t.ID)
		return
	}
	if m.notified[t.ID] == t.Status {
		return
	}
	m.notified[t.ID] = t.Status
	if !m.settings.notifyKind(kind) {
		return
	}
	fx.add(m.send(p))
}

func lastCheck(t *Task) string {
	for _, r := range t.Runs {
		if n := len(r.Checks); n > 0 && r.Status == StatusReview {
			return r.Checks[n-1].Status
		}
	}
	return ""
}
