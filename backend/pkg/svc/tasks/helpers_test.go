package tasks

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/svc/agents"
	"yozakura/backend/pkg/svc/notify"
)

// fakeAgents stands in for agents.Manager: each Send runs the test's
// script for that session in a goroutine; the script emits events.
type fakeAgents struct {
	mu        sync.Mutex
	listeners []func(string, any)
	hook      agents.PermissionHook
	sessions  map[string]agents.SessionMeta
	sends     []sentMsg
	closed    map[string]bool
	n         int
	script    func(f *fakeAgents, s agents.SessionMeta, text string, turn int)
	turns     map[string]int
}

type sentMsg struct{ session, text string }

func newFakeAgents() *fakeAgents {
	return &fakeAgents{sessions: map[string]agents.SessionMeta{}, closed: map[string]bool{}, turns: map[string]int{}}
}

func (f *fakeAgents) Create(p agents.CreateParams) (agents.SessionMeta, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if p.Yolo == nil || *p.Yolo {
		return agents.SessionMeta{}, errors.New("tasks must not use yolo")
	}
	f.n++
	meta := agents.SessionMeta{ID: fmt.Sprintf("s%d", f.n), Agent: p.Agent, Cwd: p.Cwd, Mode: p.Mode}
	f.sessions[meta.ID] = meta
	return meta, nil
}

func (f *fakeAgents) Send(id, text string, _ []string) error {
	f.mu.Lock()
	meta, ok := f.sessions[id]
	f.sends = append(f.sends, sentMsg{id, text})
	turn := f.turns[id]
	f.turns[id]++
	script := f.script
	f.mu.Unlock()
	if !ok {
		return errors.New("unknown session")
	}
	f.emit(id, agents.Event{Kind: agents.KindUser, Text: text})
	if script != nil {
		go script(f, meta, text, turn)
	}
	return nil
}

func (f *fakeAgents) Cancel(string) error { return nil }

func (f *fakeAgents) CloseSession(id string) error {
	f.mu.Lock()
	f.closed[id] = true
	f.mu.Unlock()
	return nil
}

func (f *fakeAgents) Debug(id string, _ int) (agents.DebugInfo, error) {
	return agents.DebugInfo{Session: id, LogTail: []string{"x"}, Argv: []string{"claude", "-p"}}, nil
}

func (f *fakeAgents) AddListener(fn func(string, any)) {
	f.mu.Lock()
	f.listeners = append(f.listeners, fn)
	f.mu.Unlock()
}

func (f *fakeAgents) SetPermissionHook(h agents.PermissionHook) {
	f.mu.Lock()
	f.hook = h
	f.mu.Unlock()
}

func (f *fakeAgents) emit(id string, ev agents.Event) {
	ev.Session = id
	f.mu.Lock()
	ls := append([]func(string, any){}, f.listeners...)
	f.mu.Unlock()
	for _, l := range ls {
		l("agents.event", ev)
	}
}

// reply emits an assistant answer and the end of the turn.
func (f *fakeAgents) reply(id, text string) {
	f.emit(id, agents.Event{Kind: agents.KindText, Text: text, Delta: true})
	// The top-level figures are the agent's running totals (ignored); the
	// turn's share is what a task adds up.
	cost := 0.01
	f.emit(id, agents.Event{Kind: agents.KindDone, Usage: &agents.Usage{InputTokens: 900, OutputTokens: 500, CostUSD: 7,
		Turn: &agents.TurnUsage{InputTokens: 10, OutputTokens: 5, CostUSD: &cost}}})
}

func (f *fakeAgents) sent() []sentMsg {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]sentMsg{}, f.sends...)
}

type notes struct {
	mu   sync.Mutex
	list []notify.SendParams
}

func (n *notes) add(p notify.SendParams) {
	n.mu.Lock()
	n.list = append(n.list, p)
	n.mu.Unlock()
}

func (n *notes) find(summary string) *notify.SendParams {
	n.mu.Lock()
	defer n.mu.Unlock()
	for i := range n.list {
		if strings.Contains(n.list[i].Summary, summary) {
			return &n.list[i]
		}
	}
	return nil
}

// testRepo creates a git repository with one commit.
func testRepo(t *testing.T) string {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "proj")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	run(t, dir, "git", "init", "-q", "-b", "main")
	run(t, dir, "git", "config", "user.name", "Test")
	run(t, dir, "git", "config", "user.email", "test@example.com")
	writeFile(t, filepath.Join(dir, "README.md"), "hello\n")
	run(t, dir, "git", "add", "-A")
	run(t, dir, "git", "commit", "-q", "-m", "init")
	return dir
}

func run(t *testing.T, dir string, name string, args ...string) string {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s %v: %v\n%s", name, args, err, out)
	}
	return strings.TrimSpace(string(out))
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

type env struct {
	m     *Manager
	fa    *fakeAgents
	notes *notes
	repo  string
	bus   *bus
}

type bus struct {
	mu    sync.Mutex
	kinds map[string]int
}

func (b *bus) push(kind string, _ any) {
	b.mu.Lock()
	if b.kinds == nil {
		b.kinds = map[string]int{}
	}
	b.kinds[kind]++
	b.mu.Unlock()
}

func (b *bus) count(kind string) int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.kinds[kind]
}

func newEnv(t *testing.T, script func(f *fakeAgents, s agents.SessionMeta, text string, turn int)) *env {
	t.Helper()
	repo := testRepo(t)
	fa := newFakeAgents()
	fa.script = script
	n := &notes{}
	root := t.TempDir()
	m := New(Options{Dir: filepath.Join(root, "tasks"), WorktreeRoot: filepath.Join(root, "worktrees"), Agents: fa,
		Notify: n.add, Templates: TemplateDirs{Bundled: bundledTemplates(t)}})
	b := &bus{}
	m.SetBroadcast(b.push)
	t.Cleanup(m.Close)
	empty := ""
	if _, err := m.SetProject(ProjectPatch{Dir: repo, CheckCommand: &empty}); err != nil {
		t.Fatal(err)
	}
	return &env{m: m, fa: fa, notes: n, repo: repo, bus: b}
}

func bundledTemplates(t *testing.T) string {
	p, err := filepath.Abs("../../../../assets/ai/task-templates")
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func (e *env) setCheck(t *testing.T, cmd string, attempts int) {
	t.Helper()
	if _, err := e.m.SetProject(ProjectPatch{Dir: e.repo, CheckCommand: &cmd, MaxAttempts: &attempts}); err != nil {
		t.Fatal(err)
	}
}

func waitTask(t *testing.T, m *Manager, id, what string, cond func(Task) bool) Task {
	t.Helper()
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		if tk, err := m.Get(id); err == nil && cond(tk) {
			return tk
		}
		time.Sleep(10 * time.Millisecond)
	}
	tk, _ := m.Get(id)
	t.Fatalf("timed out waiting for %s; task status %s runs %+v", what, tk.Status, runsOf(tk))
	return tk
}

func runsOf(t Task) []Run {
	out := []Run{}
	for _, r := range t.Runs {
		out = append(out, *r)
	}
	return out
}

func statusIs(st string) func(Task) bool { return func(t Task) bool { return t.Status == st } }
