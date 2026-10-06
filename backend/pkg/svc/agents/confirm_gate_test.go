package agents

import (
	"sync"
	"testing"
)

type fakeGate struct {
	mu      sync.Mutex
	allowed []string
}

func (g *fakeGate) NeedsConfirm(tool string, input map[string]any) bool {
	return tool == "routine_run" && input["id"] == "risky"
}

func (g *fakeGate) Allowed(tool string, input map[string]any) {
	g.mu.Lock()
	g.allowed = append(g.allowed, tool+":"+input["id"].(string))
	g.mu.Unlock()
}

func gateSession(t *testing.T, mode string, yolo bool) (*Manager, *session, *fakeGate) {
	t.Helper()
	m := NewManager(t.TempDir())
	m.Configure(Config{Policy: &Policy{AutoApprove: []string{CatRead, CatMCP}}})
	g := &fakeGate{}
	m.SetConfirmGate(g)
	meta, err := m.Create(CreateParams{Agent: "claude", Cwd: t.TempDir(), Mode: mode})
	if err != nil {
		t.Fatal(err)
	}
	s := m.sessions[meta.ID]
	s.meta.Yolo = yolo
	return m, s, g
}

func ask(s *session, id, tool string, in map[string]any) *string {
	d := new(string)
	*d = "pending"
	req := PermissionRequest{ID: id, Tool: tool, Category: Classify(tool, in), Input: in, RuleKey: ruleKey(tool, CatMCP, in)}
	(&sessionSink{s: s, gen: s.gen}).Permission(req, func(x string) { *d = x })
	return d
}

func TestConfirmBeatsYoloAndGateGrants(t *testing.T) {
	m, s, g := gateSession(t, ModeAgent, true)
	// Plain tools follow YOLO; confirm tools and gated routines ask.
	if d := ask(s, "a", "mcp__"+YozakuraMCPName+"__volume_set", map[string]any{}); *d != DecisionAllow {
		t.Fatalf("yolo volume_set = %q", *d)
	}
	closeApp := ask(s, "b", "mcp__"+YozakuraMCPName+"__app_close", map[string]any{"app": "x"})
	risky := ask(s, "c", "mcp__"+YozakuraMCPName+"__routine_run", map[string]any{"id": "risky"})
	safe := ask(s, "d", "mcp__"+YozakuraMCPName+"__routine_run", map[string]any{"id": "calm"})
	if *closeApp != "pending" || *risky != "pending" || *safe != DecisionAllow {
		t.Fatalf("app_close=%q risky=%q calm=%q", *closeApp, *risky, *safe)
	}
	m.mu.Lock()
	p := s.pending["c"]
	m.mu.Unlock()
	if !p.req.Confirm || p.req.RuleKey != "" {
		t.Fatalf("gated request = %+v", p.req)
	}
	// "allow for session" degrades to once and the gate learns the grant.
	if err := m.Respond(s.meta.ID, "c", DecisionAllowSession); err != nil {
		t.Fatal(err)
	}
	if *risky != DecisionAllow || len(g.allowed) != 1 || g.allowed[0] != "routine_run:risky" {
		t.Fatalf("risky=%q allowed=%v", *risky, g.allowed)
	}
	if err := m.Respond(s.meta.ID, "b", DecisionDeny); err != nil {
		t.Fatal(err)
	}
	if len(g.allowed) != 1 {
		t.Fatalf("a denial is no grant: %v", g.allowed)
	}
}

func TestConfirmIgnoresHookAllowAndYoloToggle(t *testing.T) {
	m, s, _ := gateSession(t, ModeAgent, false)
	m.SetPermissionHook(func(SessionMeta, PermissionRequest) string { return DecisionAllow })
	d := ask(s, "x", "mcp__"+YozakuraMCPName+"__binds_set", map[string]any{})
	if *d != "pending" {
		t.Fatalf("a hook cannot allow a confirm tool: %q", *d)
	}
	// Turning YOLO on approves the rest, never a confirm request.
	if _, err := m.Update(UpdateParams{Session: s.meta.ID, Yolo: boolPtr(true)}); err != nil {
		t.Fatal(err)
	}
	if *d != "pending" {
		t.Fatalf("yolo toggle approved binds_set: %q", *d)
	}
}

func TestAssistantCannotTurnOnYolo(t *testing.T) {
	m, s, _ := gateSession(t, ModeAssistant, false)
	if _, err := m.Update(UpdateParams{Session: s.meta.ID, Yolo: boolPtr(true)}); err == nil {
		t.Fatal("assistant sessions must reject YOLO")
	}
	if _, err := m.Update(UpdateParams{Session: s.meta.ID, Yolo: boolPtr(false)}); err != nil {
		t.Fatalf("turning it off is fine: %v", err)
	}
}

func TestSandboxNeverAuto(t *testing.T) {
	p := Policy{AutoApprove: []string{CatRead, CatNetwork, CatSandbox}}
	if d := p.Decide(PermissionRequest{Tool: "permissions", Category: CatSandbox}, false, nil); d != "" {
		t.Fatalf("sandbox widening = %q", d)
	}
}

func TestRespondTwiceReportsNotPending(t *testing.T) {
	m, s, _ := gateSession(t, ModeAgent, false)
	_ = ask(s, "x", "mcp__"+YozakuraMCPName+"__binds_set", map[string]any{})
	if err := m.Respond(s.meta.ID, "x", DecisionDeny); err != nil {
		t.Fatal(err)
	}
	if err := m.Respond(s.meta.ID, "x", DecisionAllow); err != ErrNotPending {
		t.Fatalf("second answer: %v", err)
	}
}
