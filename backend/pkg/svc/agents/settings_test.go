package agents

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestSettingsBusyRejectsEntireUpdate(t *testing.T) {
	m := NewManager(t.TempDir())
	meta, err := m.Create(CreateParams{Agent: "codex", Cwd: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	m.sessions[meta.ID].meta.Status = StatusRunning
	var p UpdateParams
	_ = json.Unmarshal([]byte(`{"session":"`+meta.ID+`","title":"changed","model":"other","effort":"high"}`), &p)
	if _, err := m.Update(p); err == nil {
		t.Fatal("busy launch settings accepted")
	}
	if m.sessions[meta.ID].meta.Title != "" {
		t.Fatal("invalid update mutated title")
	}
}
func TestSettingsUnknownEffortRejected(t *testing.T) {
	m := NewManager(t.TempDir())
	var p CreateParams
	_ = json.Unmarshal([]byte(`{"agent":"codex","cwd":"`+t.TempDir()+`","effort":"imaginary"}`), &p)
	if _, err := m.Create(p); err == nil {
		t.Fatal("unknown effort accepted")
	}
}
func TestOneShotClaudeRemovesTools(t *testing.T) {
	args := claudeArgs(StartOptions{Mode: "oneshot"}, "empty.json")
	found := false
	for i, arg := range args {
		if arg == "--tools" && i+1 < len(args) && args[i+1] == "" {
			found = true
		}
	}
	if !found {
		t.Fatal("oneshot retains built-in tools")
	}
	if claudeMCPConfig(StartOptions{Mode: "oneshot"}) == nil {
		t.Fatal("oneshot does not clear inherited MCP")
	}
}

func TestOneShotPermissionCannotUseYolo(t *testing.T) {
	m := NewManager(t.TempDir())
	meta, err := m.Create(CreateParams{Agent: "claude", Cwd: t.TempDir(), Mode: "oneshot", Yolo: boolPtr(true)})
	if err != nil {
		t.Fatal(err)
	}
	s := m.sessions[meta.ID]
	decision := ""
	(&sessionSink{s: s, gen: s.gen}).Permission(PermissionRequest{ID: "write", Category: CatWrite}, func(d string) { decision = d })
	if decision != DecisionDeny {
		t.Fatalf("oneshot tool decision = %q", decision)
	}
}
func TestACPCatalogUsesSemanticIDs(t *testing.T) {
	catalog := acpCatalog([]acpConfigOption{{ID: "provider-model", Category: "model", Type: "select", CurrentValue: "m", Options: []acpOptionValue{{Value: "m", Name: "Model"}}}, {ID: "quality", Category: "thought_level", Type: "select", CurrentValue: "low", Options: []acpOptionValue{{Value: "low"}, {Value: "high"}}}})
	if len(catalog.Models) != 1 || len(catalog.Models[0].Efforts) != 2 || catalog.Models[0].DefaultEffort != "low" {
		t.Fatalf("catalog=%+v", catalog)
	}
}
func TestSettingsUnsupportedPromptRejectsAtomicUpdate(t *testing.T) {
	m := NewManager(t.TempDir())
	meta, err := m.Create(CreateParams{Agent: "opencode", Cwd: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	title, prompt := "changed", "instructions"
	if _, err := m.Update(UpdateParams{Session: meta.ID, Title: &title, SystemPrompt: &prompt}); err == nil {
		t.Fatal("unsupported ACP system prompt accepted")
	}
	if m.sessions[meta.ID].meta.Title != "" {
		t.Fatal("invalid update changed title")
	}
}

func TestCodexOneShotRestrictedProfile(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "codex", "codex_oneshot.jsonl", StartOptions{Mode: "oneshot", Yolo: func() bool { return true }}, sink)
	_ = c.Send("explain", nil)
	waitFor(t, "quick done", func() bool { return sink.count(KindDone) > 0 })
	in := f.stdin()
	for _, want := range []string{`"sandbox":"read-only"`, `"approvalPolicy":"never"`, `"mcp_servers.\"inherited\".enabled":false`, `"type":"restricted"`, `"readableRoots":[]`} {
		if !strings.Contains(in, want) {
			t.Errorf("profile missing %s: %s", want, in)
		}
	}
	if !strings.Contains(strings.Join(f.args(), " "), "features.shell_tool=false") {
		t.Fatal("shell tool left enabled")
	}
}
