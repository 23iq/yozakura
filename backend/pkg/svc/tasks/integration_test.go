package tasks

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/svc/agents"
)

// TestWithRealAgentsManager drives a task through the real agents manager
// and the Claude adapter against a recorded fake CLI: the Write inside the
// worktree is auto-approved by the tasks hook, `git push` waits for the user.
func TestWithRealAgentsManager(t *testing.T) {
	bin, _ := filepath.Abs("../agents/testdata/fakecli.sh")
	fixture, _ := filepath.Abs("testdata/claude_task.jsonl")
	stdinLog := filepath.Join(t.TempDir(), "stdin.log")
	t.Setenv("FAKECLI_FIXTURE", fixture)
	t.Setenv("FAKECLI_STDIN_LOG", stdinLog)

	am := agents.NewManager(filepath.Join(t.TempDir(), "agents"))
	am.Configure(agents.Config{Agents: map[string]agents.AgentConfig{"claude": {Binary: bin}}})
	t.Cleanup(am.Shutdown)
	repo := testRepo(t)
	n := &notes{}
	root := t.TempDir()
	m := New(Options{Dir: filepath.Join(root, "tasks"), WorktreeRoot: filepath.Join(root, "wt"), Agents: am, Notify: n.add})
	t.Cleanup(m.Close)
	none := ""
	if _, err := m.SetProject(ProjectPatch{Dir: repo, CheckCommand: &none}); err != nil {
		t.Fatal(err)
	}

	tk, err := m.Create(CreateParams{Dir: repo, Prompt: "Add hello", Agent: "claude"})
	if err != nil {
		t.Fatal(err)
	}
	tk = waitTask(t, m, tk.ID, "waiting for git push", statusIs(StatusWaiting))
	r := tk.Runs[0]
	log, _ := os.ReadFile(stdinLog)
	if !strings.Contains(string(log), `"behavior":"allow"`) {
		t.Fatalf("the Write was not auto-approved: %s", log)
	}
	sess := am.Sessions()
	if len(sess) != 1 || sess[0].Cwd != r.Worktree || sess[0].Yolo || sess[0].Mode != agents.ModeAgent {
		t.Fatalf("agent session: %+v", sess)
	}
	dbg, err := m.Debug(tk.ID, 0, 20)
	if err != nil || !dbg.Running || len(dbg.Argv) == 0 || len(dbg.LogTail) == 0 || dbg.LogPath == "" {
		t.Fatalf("debug: %+v %v", dbg, err)
	}
	if err := am.Respond(r.SessionID, r.Pending[0], agents.DecisionDeny); err != nil {
		t.Fatal(err)
	}
	tk = waitTask(t, m, tk.ID, "review", statusIs(StatusReview))
	r = tk.Runs[0]
	if r.CommitMessage != "Add hello" || r.Cost.OutputTokens != 2 || len(r.Checks) != 1 || r.Checks[0].Status != CheckSkipped {
		t.Fatalf("run: %+v", r)
	}
	if n.find("is waiting") == nil {
		t.Fatal("no permission notification")
	}
}
