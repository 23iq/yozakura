package tasks

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/svc/agents"
)

// TestLiveAgent runs one tiny task end to end with a real CLI agent
// (YOZ_LIVE_AGENT=claude|codex) in a throwaway repo: worktree, agent run,
// check, review, accept. Skipped unless the variable is set; it costs a
// few cents of the agent's subscription.
func TestLiveAgent(t *testing.T) {
	agent := os.Getenv("YOZ_LIVE_AGENT")
	if agent == "" {
		t.Skip("set YOZ_LIVE_AGENT=claude|codex to run a real agent")
	}
	bin, err := exec.LookPath(agent)
	if err != nil {
		t.Skip(agent + " not installed")
	}
	am := agents.NewManager(filepath.Join(t.TempDir(), "agents"))
	am.Configure(agents.Config{Agents: map[string]agents.AgentConfig{agent: {Binary: bin}}})
	t.Cleanup(am.Shutdown)
	repo := testRepo(t)
	root := t.TempDir()
	n := &notes{}
	m := New(Options{Dir: filepath.Join(root, "tasks"), WorktreeRoot: filepath.Join(root, "wt"), Agents: am, Notify: n.add})
	t.Cleanup(m.Close)
	check := "grep -qx hi hello.txt"
	if _, err := m.SetProject(ProjectPatch{Dir: repo, CheckCommand: &check}); err != nil {
		t.Fatal(err)
	}
	tk, err := m.Create(CreateParams{Dir: repo, Prompt: "Create a file hello.txt containing exactly the line: hi", Agent: agent})
	if err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(4 * time.Minute)
	for time.Now().Before(deadline) {
		tk, _ = m.Get(tk.ID)
		if tk.Status == StatusReview || terminalStatus(tk.Status) || tk.Status == StatusWaiting {
			break
		}
		time.Sleep(500 * time.Millisecond)
	}
	r := tk.Runs[0]
	t.Logf("status %s check %+v summary %q message %q cost %+v", tk.Status, r.Checks, r.Summary, r.CommitMessage, tk.Cost)
	if tk.Status != StatusReview {
		dbg, _ := m.Debug(tk.ID, 0, 40)
		t.Fatalf("not in review: %s %s; debug %+v", tk.Status, tk.Error, dbg)
	}
	if len(r.Checks) == 0 || r.Checks[len(r.Checks)-1].Status != CheckPass {
		t.Fatalf("check: %+v", r.Checks)
	}
	diff, err := m.Diff(tk.ID, 0)
	if err != nil || !strings.Contains(diff, "hello.txt") {
		t.Fatalf("diff %q %v", diff, err)
	}
	if _, err := m.Accept(AcceptParams{ID: tk.ID, Run: 0}); err != nil {
		t.Fatal(err)
	}
	out, _ := exec.Command("git", "-C", repo, "log", "-1", "--format=%s", "--name-only").Output()
	data, _ := os.ReadFile(filepath.Join(repo, "hello.txt"))
	t.Logf("accepted: %s", out)
	if strings.TrimSpace(string(data)) != "hi" || !strings.Contains(string(out), "hello.txt") {
		t.Fatalf("accept: %q %q", data, out)
	}
}
