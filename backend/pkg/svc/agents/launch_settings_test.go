package agents

import (
	"os"
	"path/filepath"
	"testing"
)

// Sessions stored by older versions in the "shell" mode load as assistant sessions.
func TestLegacyShellSessionsLoadAsAssistant(t *testing.T) {
	dir := t.TempDir()
	data := `[{"id":"old","agent":"claude","cwd":"/tmp","mode":"shell"},{"id":"code","agent":"codex","cwd":"/tmp","mode":"agent"}]`
	if err := os.WriteFile(filepath.Join(dir, "sessions.json"), []byte(data), 0o600); err != nil {
		t.Fatal(err)
	}
	m := NewManager(dir)
	if got := m.sessions["old"].meta.Mode; got != ModeAssistant {
		t.Errorf("legacy shell session mode = %q", got)
	}
	if got := m.sessions["code"].meta.Mode; got != ModeAgent {
		t.Errorf("agent session mode = %q", got)
	}
	if err := validateLaunch(Lookup("claude"), "shell", ""); err != nil {
		t.Errorf("legacy shell mode rejected: %v", err)
	}
	if err := validateLaunch(Lookup("claude"), "bogus", ""); err == nil {
		t.Error("unknown mode accepted")
	}
}
