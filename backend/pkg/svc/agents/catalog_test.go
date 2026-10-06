package agents

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func catalogFake(t *testing.T, fixture string) StartOptions {
	t.Helper()
	f := newFake(t, "codex_start_fail.jsonl")
	path := filepath.Join(f.dir, "catalog.jsonl")
	if err := os.WriteFile(path, []byte(fixture), 0600); err != nil {
		t.Fatal(err)
	}
	f.env[0] = "FAKECLI_FIXTURE=" + path
	return StartOptions{Binary: f.bin, Cwd: f.dir, Env: f.env}
}
func TestCodexCatalogWithoutThread(t *testing.T) {
	o := catalogFake(t, "<\n{\"id\":1,\"result\":{}}\n<\n<\n{\"id\":2,\"result\":{\"data\":[{\"id\":\"picker\",\"model\":\"native\",\"displayName\":\"Native\",\"isDefault\":true,\"defaultReasoningEffort\":\"low\",\"supportedReasoningEfforts\":[{\"reasoningEffort\":\"low\"},{\"reasoningEffort\":\"high\"}]}],\"nextCursor\":null}}\n=hold\n")
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	cat, err := (codexAdapter{}).Models(ctx, o)
	if err != nil {
		t.Fatal(err)
	}
	if len(cat.Models) != 1 || cat.Models[0].ID != "native" || len(cat.Models[0].Efforts) != 2 {
		t.Fatalf("catalog=%+v", cat)
	}
	data, _ := os.ReadFile(filepath.Join(o.Cwd, "stdin.log"))
	if strings.Contains(string(data), "thread/") {
		t.Fatal("model discovery opened a thread")
	}
}
func TestClaudeCatalogEffortFromInstalledProtocol(t *testing.T) {
	o := catalogFake(t, "<\n{\"type\":\"control_response\",\"response\":{\"subtype\":\"success\",\"request_id\":\"catalog\",\"response\":{\"models\":[{\"value\":\"default\",\"displayName\":\"Default\",\"supportsEffort\":true,\"supportedEffortLevels\":[\"low\",\"high\"]},{\"value\":\"fast\",\"displayName\":\"Fast\"}]}}}\n=hold\n")
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	cat, err := (claudeAdapter{}).Models(ctx, o)
	if err != nil {
		t.Fatal(err)
	}
	if !cat.ManualModel || len(cat.Models) != 2 || len(cat.Models[0].Efforts) != 2 || len(cat.Models[1].Efforts) != 0 {
		t.Fatalf("catalog=%+v", cat)
	}
}
func TestDiscoveryTimeout(t *testing.T) {
	o := catalogFake(t, "=hold\n")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	_, err := (codexAdapter{}).Models(ctx, o)
	if err == nil {
		t.Fatal("hung discovery succeeded")
	}
}
func TestCodexTurnCarriesModelAndEffort(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "codex", "codex_command.jsonl", StartOptions{Model: "native", Effort: "high"}, sink)
	_ = c.Send("hi", nil)
	waitFor(t, "turn settings", func() bool { return strings.Contains(f.stdin(), `"effort":"high"`) })
	if !strings.Contains(f.stdin(), `"model":"native"`) {
		t.Fatal("model omitted")
	}
}
func TestClaudeEffortArg(t *testing.T) {
	args := claudeArgs(StartOptions{Effort: "high"}, "")
	if !strings.Contains(strings.Join(args, " "), "--effort high") {
		t.Fatal("effort omitted")
	}
}

func TestSettingsPersistAndIsolateEffort(t *testing.T) {
	o := catalogFake(t, "<\n{\"type\":\"control_response\",\"response\":{\"subtype\":\"success\",\"request_id\":\"catalog\",\"response\":{\"models\":[{\"value\":\"default\",\"displayName\":\"Default\",\"supportsEffort\":true,\"supportedEffortLevels\":[\"low\",\"high\"]}]}}}\n=hold\n")
	dir := t.TempDir()
	m := NewManager(dir)
	m.cfg = Config{Agents: map[string]AgentConfig{"claude": {Binary: o.Binary}}}
	m.extraEnv = o.Env
	first, err := m.Create(CreateParams{Agent: "claude", Cwd: o.Cwd, Effort: "low"})
	if err != nil {
		t.Fatal(err)
	}
	other, err := m.Create(CreateParams{Agent: "claude", Cwd: o.Cwd})
	if err != nil {
		t.Fatal(err)
	}
	high := "high"
	updated, err := m.Update(UpdateParams{Session: first.ID, Effort: &high})
	if err != nil {
		t.Fatal(err)
	}
	if updated.Effort != "high" || m.sessions[other.ID].meta.Effort != "" {
		t.Fatal("settings crossed sessions")
	}
	loaded := NewManager(dir)
	if loaded.sessions[first.ID].meta.Effort != "high" {
		t.Fatal("effort not persisted")
	}
	invalid, title := "unknown", "should not apply"
	if _, err := m.Update(UpdateParams{Session: first.ID, Title: &title, Effort: &invalid}); err == nil {
		t.Fatal("invalid effort accepted")
	}
	if m.sessions[first.ID].meta.Title == title || m.sessions[first.ID].meta.Effort != "high" {
		t.Fatal("invalid update partially applied")
	}
}
