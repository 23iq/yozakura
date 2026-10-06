package tasks

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/svc/agents"
)

const doneText = "Added hello.txt.\n\n```commit\nAdd hello file\n\nIt says hi.\n```"

// writer writes hello.txt in its worktree and finishes.
func writer(f *fakeAgents, s agents.SessionMeta, _ string, _ int) {
	_ = os.WriteFile(filepath.Join(s.Cwd, "hello.txt"), []byte("hi\n"), 0o644)
	f.reply(s.ID, doneText)
}

func TestRunReviewAccept(t *testing.T) {
	e := newEnv(t, writer)
	e.setCheck(t, "test -f hello.txt", 2)
	tk, err := e.m.Create(CreateParams{Dir: e.repo, Prompt: "Add a hello file", Agent: "claude"})
	if err != nil {
		t.Fatal(err)
	}
	r0 := tk.Runs[0]
	if !strings.HasPrefix(r0.Branch, "yoz/"+tk.ID) || !strings.Contains(r0.Worktree, tk.ID) || r0.Worktree == e.repo {
		t.Fatalf("worktree/branch: %+v", r0)
	}
	tk = waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	r := tk.Runs[0]
	if len(r.Checks) != 1 || r.Checks[0].Status != CheckPass {
		t.Fatalf("checks: %+v", r.Checks)
	}
	if r.CommitMessage != "Add hello file\n\nIt says hi." || r.Summary != "Added hello.txt." {
		t.Fatalf("summary %q message %q", r.Summary, r.CommitMessage)
	}
	if r.Changes == nil || r.Changes.Files != 1 || r.Changes.Paths[0] != "hello.txt" {
		t.Fatalf("changes: %+v", r.Changes)
	}
	if tk.Cost.InputTokens != 10 || tk.Cost.OutputTokens != 5 || tk.Cost.CostUSD != 0.01 {
		t.Fatalf("cost: %+v", tk.Cost)
	}
	first := e.fa.sent()[0].text
	if !strings.Contains(first, "Add a hello file") || !strings.Contains(first, "`commit`") {
		t.Fatalf("prompt: %q", first)
	}
	if e.notes.find("Ready for review") == nil {
		t.Fatal("no review notification")
	}
	diff, err := e.m.Diff(tk.ID, 0)
	if err != nil || !strings.Contains(diff, "+hi") {
		t.Fatalf("diff %q %v", diff, err)
	}

	// An unrelated dirty file in the main checkout does not block accept.
	writeFile(t, filepath.Join(e.repo, "notes.txt"), "mine\n")
	tk, err = e.m.Accept(AcceptParams{ID: tk.ID, Run: 0})
	if err != nil {
		t.Fatal(err)
	}
	if tk.Status != StatusAccepted || tk.CommitSHA == "" || tk.Runs[0].Status != StatusAccepted {
		t.Fatalf("accepted: %+v", tk)
	}
	if msg := run(t, e.repo, "git", "log", "-1", "--format=%s"); msg != "Add hello file" {
		t.Fatalf("commit subject %q", msg)
	}
	if n := run(t, e.repo, "git", "rev-list", "--count", "HEAD"); n != "2" {
		t.Fatalf("expected one squashed commit, have %s commits", n)
	}
	if b, _ := os.ReadFile(filepath.Join(e.repo, "hello.txt")); string(b) != "hi\n" {
		t.Fatalf("hello.txt in checkout: %q", b)
	}
	if _, err := os.Stat(r.Worktree); !os.IsNotExist(err) {
		t.Fatal("worktree not removed")
	}
	if out := run(t, e.repo, "git", "branch", "--list", "yoz/*"); out != "" {
		t.Fatalf("branch left: %q", out)
	}
	if b, _ := os.ReadFile(filepath.Join(e.repo, "notes.txt")); string(b) != "mine\n" {
		t.Fatal("unrelated local change lost")
	}
}

func TestVerifyLoopSendsFailureBack(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, text string, turn int) {
		if turn == 1 { // the fix turn
			_ = os.WriteFile(filepath.Join(s.Cwd, "fixed.txt"), []byte("ok\n"), 0o644)
		}
		f.reply(s.ID, doneText)
	})
	e.setCheck(t, "echo boom-output; test -f fixed.txt", 2)
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "fix it", Agent: "codex"})
	tk = waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	r := tk.Runs[0]
	if r.Attempts != 1 || len(r.Checks) != 2 || r.Checks[0].Status != CheckFail || r.Checks[1].Status != CheckPass {
		t.Fatalf("run: %+v", r)
	}
	sends := e.fa.sent()
	if len(sends) != 2 || !strings.Contains(sends[1].text, "boom-output") || !strings.Contains(sends[1].text, "fix attempt 1 of 2") {
		t.Fatalf("fix prompt: %+v", sends)
	}
	if sends[0].session != sends[1].session {
		t.Fatal("the fix must go to the same session")
	}
}

func TestVerifyLoopGivesUpAfterMaxAttempts(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) { f.reply(s.ID, "done") })
	e.setCheck(t, "exit 3", 1)
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	tk = waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	r := tk.Runs[0]
	if r.Attempts != 1 || len(r.Checks) != 2 || r.Checks[1].Status != CheckFail || r.Checks[1].ExitCode != 3 {
		t.Fatalf("run: %+v", r)
	}
	if _, err := e.m.Accept(AcceptParams{ID: tk.ID}); err == nil || !strings.Contains(err.Error(), "no changes") {
		t.Fatalf("accept without changes: %v", err)
	}
}

func TestPlanModeEditAndRun(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, text string, turn int) {
		if turn == 0 {
			f.reply(s.ID, "Here is my plan:\n1. Read the code\n2. Write hello.txt\n   with a greeting\n")
			return
		}
		writer(f, s, text, turn)
	})
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "Greet", Agent: "claude", Mode: ModePlan})
	tk = waitTask(t, e.m, tk.ID, "plan", statusIs(StatusAwaitingPlan))
	if len(tk.Plan) != 2 || tk.Plan[1] != "Write hello.txt with a greeting" {
		t.Fatalf("plan: %q", tk.Plan)
	}
	if !strings.Contains(e.fa.sent()[0].text, "PLAN MODE") {
		t.Fatal("plan prompt missing")
	}
	// While planning, writes are refused by the hook; reads fall through.
	sid := tk.Runs[0].SessionID
	if d := e.m.scopes.decide(agents.SessionMeta{ID: sid}, agents.PermissionRequest{Category: agents.CatWrite, Path: "a"}); d != agents.DecisionDeny {
		t.Fatalf("plan write: %q", d)
	}
	if e.notes.find("Plan ready") == nil {
		t.Fatal("no plan notification")
	}
	if _, err := e.m.UpdatePlan(tk.ID, []string{"Write hello.txt", " ", "Done"}); err != nil {
		t.Fatal(err)
	}
	if _, err := e.m.Run(tk.ID, nil); err != nil {
		t.Fatal(err)
	}
	tk = waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	sends := e.fa.sent()
	if len(sends) != 2 || sends[1].session != sid || !strings.Contains(sends[1].text, "1. Write hello.txt\n2. Done") {
		t.Fatalf("approved plan message: %+v", sends)
	}
	if d := e.m.scopes.decide(agents.SessionMeta{ID: sid}, agents.PermissionRequest{Category: agents.CatWrite, Path: "a"}); d != agents.DecisionAllow {
		t.Fatalf("work write: %q", d)
	}
}

func TestPlanModeBestOfN(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, text string, turn int) {
		if strings.Contains(text, "PLAN MODE") {
			f.reply(s.ID, "1. Write hello.txt")
			return
		}
		writer(f, s, text, turn)
	})
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "Greet", Agents: []string{"claude", "codex"}, Mode: ModePlan})
	if tk.Status == StatusAwaitingPlan {
		t.Fatal("awaiting the plan before planning")
	}
	tk = waitTask(t, e.m, tk.ID, "plan", statusIs(StatusAwaitingPlan))
	if tk.Runs[1].SessionID != "" {
		t.Fatal("the second run must wait for the plan")
	}
	if _, err := e.m.Followup(tk.ID, 1, "x"); err == nil {
		t.Fatal("followup on a run waiting for the plan accepted")
	}
	if _, err := e.m.Run(tk.ID, nil); err != nil {
		t.Fatal(err)
	}
	tk = waitTask(t, e.m, tk.ID, "both in review", func(t Task) bool {
		return t.Runs[0].Status == StatusReview && t.Runs[1].Status == StatusReview
	})
	for _, s := range e.fa.sent() {
		if s.session == tk.Runs[1].SessionID && !strings.Contains(s.text, "1. Write hello.txt") {
			t.Fatalf("second run prompt lacks the plan: %q", s.text)
		}
	}
}

func TestBestOfNAcceptOneDiscardOthers(t *testing.T) {
	e := newEnv(t, func(f *fakeAgents, s agents.SessionMeta, _ string, _ int) {
		_ = os.WriteFile(filepath.Join(s.Cwd, "hello.txt"), []byte(s.Agent+"\n"), 0o644)
		f.reply(s.ID, "done ("+s.Agent+")")
	})
	tk, err := e.m.Create(CreateParams{Dir: e.repo, Prompt: "Say hi", Agents: []string{"claude", "codex"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(tk.Runs) != 2 || tk.Runs[0].Worktree == tk.Runs[1].Worktree || !strings.HasSuffix(tk.Runs[1].Branch, "-2") {
		t.Fatalf("runs: %+v", runsOf(tk))
	}
	tk = waitTask(t, e.m, tk.ID, "both reviewed", func(t Task) bool {
		return t.Runs[0].Status == StatusReview && t.Runs[1].Status == StatusReview
	})
	tk, err = e.m.Accept(AcceptParams{ID: tk.ID, Run: 1, Message: "Use codex greeting"})
	if err != nil {
		t.Fatal(err)
	}
	if tk.Runs[0].Status != StatusDiscarded || tk.Runs[1].Status != StatusAccepted || tk.AcceptedRun != 1 {
		t.Fatalf("statuses: %+v", runsOf(tk))
	}
	if b, _ := os.ReadFile(filepath.Join(e.repo, "hello.txt")); string(b) != "codex\n" {
		t.Fatalf("accepted content %q", b)
	}
	for _, r := range tk.Runs {
		if _, err := os.Stat(r.Worktree); !os.IsNotExist(err) {
			t.Fatalf("worktree %s left", r.Worktree)
		}
	}
}

func TestAcceptRefusesDirtyAndConflicts(t *testing.T) {
	e := newEnv(t, writer)
	tk, _ := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude"})
	waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	writeFile(t, filepath.Join(e.repo, "hello.txt"), "local\n")
	_, err := e.m.Accept(AcceptParams{ID: tk.ID})
	var ce *ConflictError
	if !errors.As(err, &ce) || ce.Reason != "dirty" || ce.Paths[0] != "hello.txt" {
		t.Fatalf("dirty: %v", err)
	}
	// Committed on the main branch meanwhile -> a real conflict.
	run(t, e.repo, "git", "add", "-A")
	run(t, e.repo, "git", "commit", "-q", "-m", "local hello")
	_, err = e.m.Accept(AcceptParams{ID: tk.ID})
	if !errors.As(err, &ce) || ce.Reason != "conflict" || ce.Paths[0] != "hello.txt" {
		t.Fatalf("conflict: %v", err)
	}
	if got, _ := e.m.Get(tk.ID); got.Status != StatusReview {
		t.Fatalf("status after refused accept: %s", got.Status)
	}
	tk, err = e.m.Discard(tk.ID, -1)
	if err != nil || tk.Status != StatusDiscarded {
		t.Fatalf("discard: %v %s", err, tk.Status)
	}
	if out := run(t, e.repo, "git", "worktree", "list"); strings.Count(out, "\n") != 0 {
		t.Fatalf("worktrees left: %s", out)
	}
}

func TestInPlaceTask(t *testing.T) {
	e := newEnv(t, writer)
	tk, err := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agent: "claude", InPlace: true})
	if err != nil {
		t.Fatal(err)
	}
	if tk.Runs[0].Worktree != e.repo || tk.Runs[0].Branch != "" {
		t.Fatalf("in place run: %+v", tk.Runs[0])
	}
	tk = waitTask(t, e.m, tk.ID, "review", statusIs(StatusReview))
	if d := e.m.scopes.decide(agents.SessionMeta{ID: tk.Runs[0].SessionID}, agents.PermissionRequest{Category: agents.CatWrite, Path: "a"}); d != "" {
		t.Fatalf("in place must ask: %q", d)
	}
	if _, err := e.m.Accept(AcceptParams{ID: tk.ID}); err != nil {
		t.Fatal(err)
	}
	if msg := run(t, e.repo, "git", "log", "-1", "--format=%s"); msg != "Add hello file" {
		t.Fatalf("commit %q", msg)
	}
	if _, err := e.m.Create(CreateParams{Dir: e.repo, Prompt: "x", Agents: []string{"claude", "codex"}, InPlace: true}); err == nil {
		t.Fatal("best-of-N in place must be refused")
	}
}

func TestCreateValidation(t *testing.T) {
	e := newEnv(t, nil)
	cases := []CreateParams{
		{Dir: e.repo, Prompt: "x"},
		{Dir: e.repo, Prompt: "x", Agent: "nope"},
		{Dir: e.repo, Agent: "claude"},
		{Dir: e.repo, Prompt: "x", Agent: "claude", Mode: "later"},
		{Dir: t.TempDir(), Prompt: "x", Agent: "claude"},
		{Dir: "/does/not/exist", Prompt: "x", Agent: "claude"},
	}
	for i, c := range cases {
		if _, err := e.m.Create(c); err == nil {
			t.Errorf("case %d accepted", i)
		}
	}
}

func TestTemplateTask(t *testing.T) {
	e := newEnv(t, nil)
	writeFile(t, filepath.Join(e.repo, "README.md"), "changed\n")
	tk, err := e.m.Create(CreateParams{Dir: e.repo, Template: "review", Prompt: "focus on docs", Agent: "claude"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(tk.Prompt, "focus on docs") || !strings.Contains(tk.Prompt, "+changed") || tk.Title != "Review: focus on docs" {
		t.Fatalf("prompt %q title %q", tk.Prompt, tk.Title)
	}
}
