package agents

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSlowIPCMethodsAreAsync(t *testing.T) {
	svc := NewService(NewManager(filepath.Join(t.TempDir(), "agents"))).ipcService()
	for _, m := range []string{"list_agents", "configure"} {
		if !svc.Async[m] {
			t.Errorf("agents.%s probes agent CLIs and must not block the IPC connection", m)
		}
	}
}

func TestVersionProbesRunInParallel(t *testing.T) {
	dir := t.TempDir()
	cfg := Config{Agents: map[string]AgentConfig{}}
	for _, id := range AdapterIDs() {
		bin := filepath.Join(dir, id)
		if err := os.WriteFile(bin, []byte("#!/bin/sh\nsleep 1\necho "+id+" 1.0\n"), 0o755); err != nil {
			t.Fatal(err)
		}
		cfg.Agents[id] = AgentConfig{Binary: bin}
	}
	if len(cfg.Agents) < 2 {
		t.Skip("needs several adapters")
	}
	m := NewManager(filepath.Join(dir, "agents"))
	start := time.Now()
	m.Configure(cfg)
	if d := time.Since(start); d > 1900*time.Millisecond {
		t.Errorf("%d version probes took %v (serial?)", len(cfg.Agents), d)
	}
	for _, a := range m.ListAgents() {
		if a.Version != a.ID+" 1.0" {
			t.Errorf("version of %s = %q", a.ID, a.Version)
		}
	}
}
