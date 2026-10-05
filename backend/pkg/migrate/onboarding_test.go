package migrate

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/paths"
)

func TestEnsureOnboardingFlag(t *testing.T) {
	dir := t.TempDir()
	p := paths.Paths{ConfigDir: dir}
	file := p.Config("general")

	// Fresh install: nothing to mark, nothing created.
	if changed, err := EnsureOnboardingFlag(p); err != nil || changed {
		t.Fatalf("fresh: %v %v", changed, err)
	}
	if _, err := os.Stat(file); err == nil {
		t.Fatal("must not create general.json on a fresh install")
	}

	// Existing install without the key: added, the rest preserved in order.
	os.MkdirAll(filepath.Dir(file), 0o755)
	os.WriteFile(file, []byte(`{"terminal": "foot", "terminalAdvanced": false}`), 0o644)
	if changed, err := EnsureOnboardingFlag(p); err != nil || !changed {
		t.Fatalf("existing: %v %v", changed, err)
	}
	b, _ := os.ReadFile(file)
	s := string(b)
	if !strings.Contains(s, `"onboardingDone": true`) || !strings.Contains(s, `"terminal": "foot"`) ||
		strings.Index(s, "terminal") > strings.Index(s, "onboardingDone") {
		t.Fatalf("unexpected file: %s", s)
	}

	// Key already set (e.g. a fresh install mid-wizard): left alone.
	os.WriteFile(file, []byte(`{"onboardingDone": false}`), 0o644)
	if changed, _ := EnsureOnboardingFlag(p); changed {
		t.Fatal("an explicit value must be kept")
	}
}

func TestMarkOnboardingDoneCreateOverwrite(t *testing.T) {
	file := filepath.Join(t.TempDir(), "config", "general.json")
	if changed, err := MarkOnboardingDone(file, true, true); err != nil || !changed {
		t.Fatalf("create: %v %v", changed, err)
	}
	os.WriteFile(file, []byte(`{"onboardingDone": false}`), 0o644)
	if changed, _ := MarkOnboardingDone(file, true, true); !changed {
		t.Fatal("overwrite must replace false")
	}
	b, _ := os.ReadFile(file)
	if !strings.Contains(string(b), `"onboardingDone": true`) {
		t.Fatalf("got %s", b)
	}
}

func TestMigrateMarksOnboardingDone(t *testing.T) {
	p, l, _ := setup(t)
	os.WriteFile(filepath.Join(l.ConfigDir, "config", "general.json"), []byte(`{"terminal":"kitty","onboardingDone":false}`), 0o644)
	if res, err := Run(p, l); err != nil || !res.Migrated {
		t.Fatalf("Run: %v", err)
	}
	b, _ := os.ReadFile(filepath.Join(p.ConfigDir, "config", "general.json"))
	if !strings.Contains(string(b), `"onboardingDone": true`) || !strings.Contains(string(b), `"terminal": "kitty"`) {
		t.Fatalf("migrated general.json: %s", b)
	}
	legacy, _ := os.ReadFile(filepath.Join(l.ConfigDir, "config", "general.json"))
	if strings.Contains(string(legacy), "true") {
		t.Fatal("legacy dir must be untouched")
	}

	// Legacy install without general.json: created with the flag.
	p2, l2, _ := setup(t)
	if _, err := Run(p2, l2); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(filepath.Join(p2.ConfigDir, "config", "general.json"))
	if !strings.Contains(string(b), `"onboardingDone": true`) {
		t.Fatalf("general.json not created: %s", b)
	}
}
