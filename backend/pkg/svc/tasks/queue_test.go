package tasks

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/svc/agents"
)

func TestQueueRespectsMaxParallel(t *testing.T) {
	release := make(chan struct{})
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) {
		<-release
		f.reply(s.ID, "ok")
	})
	e.m.Configure(Settings{MaxParallel: 1})
	a, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "a", Agent: "claude"})
	b, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "b", Agent: "claude"})
	waitTask(t, e.m, a.ID, "a running", statusIs(StatusRunning))
	time.Sleep(50 * time.Millisecond)
	if got, _ := e.m.Get(b.ID); got.Status != StatusQueued {
		t.Fatalf("b should wait for a slot, is %s", got.Status)
	}
	if act := e.m.Activity(); act.Running != 1 || act.Queued != 1 || act.Headline != "running" || act.TaskID != a.ID {
		t.Fatalf("activity: %+v", act)
	}
	close(release)
	waitTask(t, e.m, a.ID, "a review", statusIs(StatusReview))
	waitTask(t, e.m, b.ID, "b review", statusIs(StatusReview))
	if e.bus.count("tasks.activity") == 0 || e.bus.count("tasks.updated") == 0 {
		t.Fatal("no broadcasts")
	}
}

func TestRateLimitParksAndResumes(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, turn int) {
		if turn == 0 {
			at := time.Now().Add(time.Second).Unix()
			f.emit(s.ID, agents.Event{Kind: agents.KindError, Message: fmt.Sprintf("Claude AI usage limit reached|%d", at)})
			f.emit(s.ID, agents.Event{Kind: agents.KindDone})
			return
		}
		f.reply(s.ID, "finished")
	})
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	tk = waitTask(t, e.m, tk.ID, "limit", statusIs(StatusWaitingLimit))
	if tk.Runs[0].ResetsAt == 0 {
		t.Fatal("resetsAt unknown")
	}
	if e.notes.find("usage limit") == nil {
		t.Fatal("no limit notification")
	}
	waitTask(t, e.m, tk.ID, "review after reset", statusIs(StatusReview))
	sends := e.fa.sent()
	if len(sends) != 2 || sends[1].session != sends[0].session || !strings.Contains(sends[1].text, "limit has reset") {
		t.Fatalf("resume: %+v", sends)
	}
}

func TestRateLimitFallbackAgent(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) {
		if s.Agent == "claude" {
			at := time.Now().Add(500 * time.Millisecond).Unix()
			f.emit(s.ID, agents.Event{Kind: agents.KindError, Message: fmt.Sprintf("usage limit reached|%d", at)})
			f.emit(s.ID, agents.Event{Kind: agents.KindDone})
			return
		}
		f.reply(s.ID, "codex finished")
	})
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude", Fallback: "codex"})
	tk = waitTask(t, e.m, tk.ID, "review via fallback", statusIs(StatusReview))
	r := tk.Runs[0]
	if r.Agent != "codex" || len(r.SessionIDs) != 2 || r.Summary != "codex finished" {
		t.Fatalf("run: %+v", r)
	}
	sends := e.fa.sent()
	if !strings.Contains(sends[1].text, "hit its usage limit") {
		t.Fatalf("fallback prompt: %q", sends[1].text)
	}
}

func TestPermissionWaitingAndNotification(t *testing.T) {
	answered := make(chan struct{})
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) {
		f.emit(s.ID, agents.Event{Kind: agents.KindPermissionRequest, ID: "p1", Tool: "Bash", Title: "$ git push",
			Category: agents.CatExec})
		<-answered
		f.emit(s.ID, agents.Event{Kind: agents.KindPermissionResolved, ID: "p1", Decision: agents.DecisionDeny})
		f.reply(s.ID, "ok")
	})
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	tk = waitTask(t, e.m, tk.ID, "waiting", statusIs(StatusWaiting))
	if len(tk.Runs[0].Pending) != 1 {
		t.Fatalf("pending: %v", tk.Runs[0].Pending)
	}
	if act := e.m.Activity(); act.Headline != "waiting" || act.Agent != "Claude Code" {
		t.Fatalf("activity: %+v", act)
	}
	var n = e.notes.find("is waiting")
	for i := 0; n == nil && i < 100; i++ {
		time.Sleep(10 * time.Millisecond)
		n = e.notes.find("is waiting")
	}
	if n == nil || len(n.Actions) != 3 || n.Actions[0].Call.Method != "agents.respond" {
		t.Fatalf("notification: %+v", n)
	}
	params := n.Actions[0].Call.Params.(map[string]any)
	if params["session"] != tk.Runs[0].SessionID || params["request"] != "p1" || params["decision"] != "allow" {
		t.Fatalf("allow params: %+v", params)
	}
	close(answered)
	waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
}

func TestAgentExitFailsRunAndFollowupRetries(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, turn int) {
		if turn == 0 {
			f.emit(s.ID, agents.Event{Kind: agents.KindError, Message: "claude exited: boom"})
			f.emit(s.ID, agents.Event{Kind: agents.KindStatus, Status: agents.StatusExited})
			return
		}
		f.reply(s.ID, "second try ok")
	})
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	tk = waitTask(t, e.m, tk.ID, "failed", statusIs(StatusFailed))
	if !strings.Contains(tk.Error, "boom") {
		t.Fatalf("error: %q", tk.Error)
	}
	if e.notes.find("Task failed") == nil {
		t.Fatal("no failure notification")
	}
	if _, err := e.m.Followup(tk.ID, 0, "try again please"); err != nil {
		t.Fatal(err)
	}
	tk = waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	sends := e.fa.sent()
	if !strings.Contains(sends[len(sends)-1].text, "try again please") {
		t.Fatalf("followup: %+v", sends)
	}
	if _, err := e.m.Followup(tk.ID, 0, ""); err == nil {
		t.Fatal("empty followup accepted")
	}
}

func TestCancelStopsRuns(t *testing.T) {
	block := make(chan struct{})
	t.Cleanup(func() { close(block) })
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) { <-block })
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	waitTask(t, e.m, tk.ID, "running", func(t Task) bool { return t.Runs[0].SessionID != "" })
	tk, err := e.m.Cancel(tk.ID)
	if err != nil || tk.Status != StatusCancelled {
		t.Fatalf("cancel: %v %s", err, tk.Status)
	}
	e.fa.mu.Lock()
	closed := e.fa.closed[tk.Runs[0].SessionID]
	e.fa.mu.Unlock()
	if !closed {
		t.Fatal("session not closed")
	}
	if err := e.m.Delete(tk.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := e.m.Get(tk.ID); err == nil || e.bus.count("tasks.removed") != 1 {
		t.Fatal("task not deleted")
	}
}

func TestRestoreRequeuesInterruptedRuns(t *testing.T) {
	e := newEnv(t, nil) // the agent never answers: the run stays running
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	tk = waitTask(t, e.m, tk.ID, "running", func(t Task) bool { return t.Runs[0].SessionID != "" })
	e.m.Close()

	fa := newFakeAgents()
	fa.sessions[tk.Runs[0].SessionID] = agents.SessionMeta{ID: tk.Runs[0].SessionID, Agent: "claude", Cwd: tk.Runs[0].Worktree}
	fa.script = func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) { f.reply(s.ID, "resumed") }
	m2 := New(Options{Dir: e.m.opt.Dir, WorktreeRoot: e.m.opt.WorktreeRoot, Agents: fa})
	t.Cleanup(m2.Close)
	got, _ := m2.Get(tk.ID)
	if got.Status != StatusQueued {
		t.Fatalf("restored status %s", got.Status)
	}
	m2.Start()
	waitTask(t, m2, tk.ID, "review", statusIs(StatusReview))
	sends := fa.sent()
	if len(sends) != 1 || sends[0].session != tk.Runs[0].SessionID || !strings.Contains(sends[0].text, "interrupted") {
		t.Fatalf("resume: %+v", sends)
	}
	if !strings.HasPrefix(filepath.Base(m2.st.taskPath(tk.ID)), "k") {
		t.Fatal("task file naming")
	}
}
