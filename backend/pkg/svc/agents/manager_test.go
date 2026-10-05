package agents

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

type bus struct {
	mu     sync.Mutex
	events []Event
	other  map[string]int
}

func (b *bus) push(service string, data any) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if ev, ok := data.(Event); ok && service == "agents.event" {
		b.events = append(b.events, ev)
		return
	}
	if b.other == nil {
		b.other = map[string]int{}
	}
	b.other[service]++
}

func (b *bus) kinds(kind string) []Event {
	b.mu.Lock()
	defer b.mu.Unlock()
	var out []Event
	for _, e := range b.events {
		if e.Kind == kind {
			out = append(out, e)
		}
	}
	return out
}

func newTestManager(t *testing.T, fixture string) (*Manager, *bus, *fake) {
	t.Helper()
	f := newFake(t, fixture)
	m := NewManager(filepath.Join(t.TempDir(), "agents"))
	b := &bus{}
	m.SetBroadcast(b.push)
	m.extraEnv = f.env
	m.coalesce = 20e6 // 20ms
	m.SetMCPProvider(func() []MCPServer {
		return []MCPServer{{Name: YozakuraMCPName, Transport: "stdio", Command: "/bin/true", Args: []string{"mcp"}}}
	})
	m.Configure(Config{Agents: map[string]AgentConfig{
		"claude": {Binary: f.bin}, "codex": {Binary: f.bin}, "opencode": {Binary: f.bin}}})
	t.Cleanup(m.Shutdown)
	return m, b, f
}

func status(m *Manager, id string) SessionMeta {
	for _, s := range m.Sessions() {
		if s.ID == id {
			return s
		}
	}
	return SessionMeta{}
}

func TestManagerPermissionFlowAndPersistence(t *testing.T) {
	m, b, f := newTestManager(t, "claude_write_bash.jsonl")
	meta, err := m.Create(CreateParams{Agent: "claude", Cwd: f.dir})
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Send(meta.ID, "Create hello.txt please", nil); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "permission", func() bool { s := status(m, meta.ID); return s.Pending == 1 && s.Status == StatusWaiting })
	req := b.kinds(KindPermissionRequest)
	if len(req) != 1 || req[0].ID != "toolu_01FqEkkizX4EShqc1DskRxna" || req[0].Category != CatWrite || len(req[0].Options) != 3 {
		t.Fatalf("permission request = %+v", req)
	}
	if err := m.Respond(meta.ID, req[0].ID, DecisionAllowSession); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "idle", func() bool { return status(m, meta.ID).Status == StatusIdle })

	s := status(m, meta.ID)
	if s.Title != "Create hello.txt please" || s.AgentSessionID != "9f632da6-0dd2-405a-a73b-a7e1e4e23c24" || !strings.Contains(s.LastText, "Готово") {
		t.Errorf("meta = %+v", s)
	}
	if res := b.kinds(KindPermissionResolved); len(res) != 1 || res[0].Decision != DecisionAllowSession {
		t.Errorf("resolved = %+v", res)
	}
	// Seq is gapless and increasing; deltas were coalesced.
	b.mu.Lock()
	for i, e := range b.events {
		if e.Seq != int64(i+1) || e.Session != meta.ID || e.TS == 0 {
			t.Fatalf("event %d = %+v", i, e)
		}
	}
	b.mu.Unlock()
	fixture, _ := os.ReadFile("testdata/claude_write_bash.jsonl")
	if n := len(b.kinds(KindText)); n == 0 || n >= strings.Count(string(fixture), `"text_delta"`) {
		t.Errorf("text events = %d (not coalesced?)", n)
	}
	if !strings.Contains(f.stdin(), `"behavior":"allow"`) {
		t.Errorf("stdin = %s", f.stdin())
	}

	// A new manager on the same dir sees the session and its log.
	m.Shutdown()
	s = status(m, meta.ID) // includes the final "exited" status event
	m2 := NewManager(m.dir)
	s2 := status(m2, meta.ID)
	if s2.Status != StatusExited || s2.AgentSessionID != s.AgentSessionID || s2.LastSeq != s.LastSeq {
		t.Fatalf("reloaded meta = %+v", s2)
	}
	evs, last, err := m2.Events(meta.ID, 0)
	if err != nil || last != s.LastSeq || int64(len(evs)) != last || evs[0].Kind != KindUser {
		t.Fatalf("events: n=%d last=%d err=%v", len(evs), last, err)
	}
	tail, _, _ := m2.Events(meta.ID, last-2)
	if len(tail) != 2 || tail[0].Seq != last-1 {
		t.Errorf("tail = %+v", tail)
	}
}

func TestManagerResumeAndShellMode(t *testing.T) {
	m, _, f := newTestManager(t, "claude_write_bash.jsonl")
	meta, _ := m.Create(CreateParams{Agent: "claude", Cwd: f.dir, Yolo: boolPtr(true)})
	_ = m.Send(meta.ID, "hi", nil)
	waitFor(t, "idle", func() bool { return status(m, meta.ID).Status == StatusIdle })
	_ = m.CloseSession(meta.ID)
	waitFor(t, "exited", func() bool { return status(m, meta.ID).Status == StatusExited })
	_ = m.Send(meta.ID, "again", nil)
	waitFor(t, "idle again", func() bool { return status(m, meta.ID).Status == StatusIdle })
	if args := strings.Join(f.args(), " "); !strings.Contains(args, "--resume 9f632da6-0dd2-405a-a73b-a7e1e4e23c24") {
		t.Errorf("args = %s", args)
	}

	shell, err := m.Create(CreateParams{Agent: "claude", Mode: "shell"})
	if err != nil {
		t.Fatal(err)
	}
	home, _ := os.UserHomeDir()
	if shell.Cwd != home {
		t.Errorf("shell cwd = %s", shell.Cwd)
	}
	m.mu.Lock()
	opts, err := m.startOptionsLocked(m.sessions[shell.ID])
	m.mu.Unlock()
	if err != nil || opts.SystemPrompt != DefaultShellPrompt || len(opts.MCP) != 1 || opts.MCP[0].Name != YozakuraMCPName {
		t.Errorf("shell opts = %+v err=%v", opts, err)
	}
}

func TestManagerYoloAuto(t *testing.T) {
	m, b, f := newTestManager(t, "claude_write_bash.jsonl")
	meta, _ := m.Create(CreateParams{Agent: "claude", Cwd: f.dir, Yolo: boolPtr(true)})
	_ = m.Send(meta.ID, "hi", nil)
	waitFor(t, "idle", func() bool { return status(m, meta.ID).Status == StatusIdle })
	if len(b.kinds(KindPermissionRequest)) != 0 {
		t.Error("yolo must not ask")
	}
	if res := b.kinds(KindPermissionResolved); len(res) != 1 || res[0].Decision != DecisionAuto {
		t.Errorf("resolved = %+v", res)
	}
}

func TestManagerCancelAndYoloToggle(t *testing.T) {
	m, b, f := newTestManager(t, "codex_command.jsonl")
	meta, _ := m.Create(CreateParams{Agent: "codex", Cwd: f.dir})
	_ = m.Send(meta.ID, "hi", nil)
	waitFor(t, "pending", func() bool { return status(m, meta.ID).Pending == 1 })
	if err := m.Cancel(meta.ID); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "decline", func() bool { return strings.Contains(f.stdin(), `"decision":"decline"`) })
	waitFor(t, "idle", func() bool { return status(m, meta.ID).Status == StatusIdle })
	if strings.Contains(f.stdin(), "turn/interrupt") == false {
		// the turn id is known from turn/start, so an interrupt is sent
		t.Errorf("no interrupt in %s", f.stdin())
	}
	if res := b.kinds(KindPermissionResolved); len(res) != 1 || res[0].Decision != DecisionDeny {
		t.Errorf("resolved = %+v", res)
	}

	// Turning YOLO on approves what is waiting.
	m2, _, f2 := newTestManager(t, "opencode_ask.jsonl")
	meta2, _ := m2.Create(CreateParams{Agent: "opencode", Cwd: f2.dir, Model: "ollama/qwen3.5:9b"})
	_ = m2.Send(meta2.ID, "hi", nil)
	waitFor(t, "pending", func() bool { return status(m2, meta2.ID).Pending == 1 })
	if _, err := m2.Update(UpdateParams{Session: meta2.ID, Yolo: boolPtr(true)}); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "done", func() bool { return status(m2, meta2.ID).Status == StatusIdle })
	if strings.Count(f2.stdin(), `"optionId":"once"`) != 2 {
		t.Errorf("stdin = %s", f2.stdin())
	}
}

func TestManagerExitError(t *testing.T) {
	m, b, f := newTestManager(t, "claude_write_bash.jsonl")
	fx := filepath.Join(f.dir, "crash.jsonl")
	_ = os.WriteFile(fx, []byte("<\n=exit 3\n"), 0o644)
	m.extraEnv = append(append([]string{}, f.env...), "FAKECLI_FIXTURE="+fx)
	meta, _ := m.Create(CreateParams{Agent: "claude", Cwd: f.dir})
	_ = m.Send(meta.ID, "hi", nil)
	waitFor(t, "exited", func() bool { return status(m, meta.ID).Status == StatusExited })
	if errs := b.kinds(KindError); len(errs) != 1 || !strings.Contains(errs[0].Message, "claude exited") {
		t.Errorf("errors = %+v", errs)
	}
}

func TestServiceMethods(t *testing.T) {
	m, _, f := newTestManager(t, "claude_write_bash.jsonl")
	s := NewService(m)
	call := func(fn func(json.RawMessage) (any, error), params any) (any, error) {
		data, _ := json.Marshal(params)
		return fn(data)
	}
	if _, err := call(s.create, map[string]any{"agent": "nope", "cwd": f.dir}); err == nil {
		t.Error("unknown agent must fail")
	}
	if _, err := call(s.create, map[string]any{"agent": "claude"}); err == nil {
		t.Error("agent mode without cwd must fail")
	}
	res, err := call(s.create, map[string]any{"agent": "claude", "cwd": f.dir, "title": "T"})
	if err != nil {
		t.Fatal(err)
	}
	id := res.(SessionMeta).ID
	if _, err := call(s.respond, map[string]any{"session": id, "request": "x", "decision": "maybe"}); err == nil {
		t.Error("bad decision must fail")
	}
	if _, err := call(s.update, map[string]any{"session": id, "pinned": true}); err != nil || !status(m, id).Pinned {
		t.Errorf("pin failed: %v", err)
	}
	if out, err := call(s.events, map[string]any{"session": id}); err != nil || len(out.(map[string]any)["events"].([]Event)) != 0 {
		t.Errorf("events = %v %v", out, err)
	}
	if _, err := call(s.byID(m.Delete), map[string]any{"session": id}); err != nil || len(m.Sessions()) != 0 {
		t.Errorf("delete failed: %v", err)
	}
	agents := m.ListAgents()
	if len(agents) != 3 || agents[0].ID != "claude" || !agents[0].Available || agents[0].Binary != f.bin {
		t.Errorf("agents = %+v", agents)
	}
}

func boolPtr(b bool) *bool { return &b }
