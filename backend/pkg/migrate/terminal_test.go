package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/paths"
)

// An update alone never starts the greeting: on with the prompt off it
// showed nothing before and is switched off; on with the prompt on it
// keeps plain fastfetch (fish only, see termlook.GreetingAllShells).
func TestEnsureTerminalGreeting(t *testing.T) {
	p := paths.Paths{ConfigDir: t.TempDir()}
	file := p.Config("terminal")
	if changed, err := EnsureTerminalGreeting(p); err != nil || changed {
		t.Fatalf("fresh install: %v %v", changed, err)
	}
	if _, err := os.Stat(file); err == nil {
		t.Fatal("must not create terminal.json")
	}
	if err := os.MkdirAll(filepath.Dir(file), 0o755); err != nil {
		t.Fatal(err)
	}
	read := func() map[string]any {
		var m map[string]any
		b, _ := os.ReadFile(file)
		_ = json.Unmarshal(b, &m)
		return m
	}
	cases := []struct {
		in, greeting string
	}{
		{`{"enabled":false,"greeting":"fastfetch","padding":4}`, "none"}, // (b): showed nothing
		{`{"greeting":"fastfetch"}`, "none"},                             // prompt off by default
		{`{"enabled":true,"greeting":"fastfetch"}`, "fastfetch"},         // (a): fish, plain fastfetch
		{`{"enabled":true,"greeting":"none"}`, "none"},
	}
	for _, c := range cases {
		if err := os.WriteFile(file, []byte(c.in), 0o644); err != nil {
			t.Fatal(err)
		}
		if changed, err := EnsureTerminalGreeting(p); err != nil || !changed {
			t.Fatalf("%s: %v %v", c.in, changed, err)
		}
		m := read()
		if m["greeting"] != c.greeting || m["fastfetchPreset"] != "own" {
			t.Errorf("%s: %v", c.in, m)
		}
		if c.in == cases[0].in && m["padding"] != float64(4) {
			t.Errorf("other keys lost: %v", m)
		}
	}
	// once: a greeting switched on in this version (prompt off) stays on
	if err := os.WriteFile(file, []byte(`{"enabled":false,"greeting":"fastfetch","fastfetchPreset":"sakura"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if changed, err := EnsureTerminalGreeting(p); err != nil || changed {
		t.Fatalf("migrated file: %v %v", changed, err)
	}
	if m := read(); m["greeting"] != "fastfetch" {
		t.Errorf("a choice of this version was undone: %v", m)
	}
	// malformed: left for the shell
	if err := os.WriteFile(file, []byte(`{"greeting":`), 0o644); err != nil {
		t.Fatal(err)
	}
	if changed, err := EnsureTerminalGreeting(p); err != nil || changed {
		t.Fatalf("malformed: %v %v", changed, err)
	}
}
