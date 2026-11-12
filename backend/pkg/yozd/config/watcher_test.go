package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func waitApplied(t *testing.T, ch <-chan *TOMLConfig, what string) *TOMLConfig {
	t.Helper()
	select {
	case cfg := <-ch:
		return cfg
	case <-time.After(5 * time.Second):
		t.Fatalf("%s: config not applied", what)
		return nil
	}
}

// yozd starts before the shell writes its TOML on a first run: the config
// created afterwards must still be applied, and later edits too.
func TestLoadAndWatchAppliesAConfigCreatedLater(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "yozd.toml")
	applied := make(chan *TOMLConfig, 8)
	w := LoadAndWatch(path, func(cfg *TOMLConfig) { applied <- cfg })
	if w == nil {
		t.Fatal("no watcher")
	}
	defer w.Stop()
	select {
	case <-applied:
		t.Fatal("applied without a config file")
	case <-time.After(300 * time.Millisecond):
	}

	// Files next to it (the shell's state) are not the config.
	if err := os.WriteFile(filepath.Join(dir, "other.json"), []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	select {
	case <-applied:
		t.Fatal("an unrelated file triggered a reload")
	case <-time.After(500 * time.Millisecond):
	}

	// Written the way the shell does it: a temp file renamed into place.
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte("[appearance.gaps]\ninner = 3\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(tmp, path); err != nil {
		t.Fatal(err)
	}
	cfg := waitApplied(t, applied, "created")
	if cfg.Appearance == nil || cfg.Appearance.Gaps == nil || *cfg.Appearance.Gaps.Inner != 3 {
		t.Fatalf("created config not loaded: %+v", cfg)
	}

	if err := os.WriteFile(path, []byte("[appearance.gaps]\ninner = 4\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	waitApplied(t, applied, "edited")
}

func TestLoadAndWatchAppliesAnExistingConfigAtOnce(t *testing.T) {
	path := filepath.Join(t.TempDir(), "yozd.toml")
	if err := os.WriteFile(path, []byte("[appearance.gaps]\ninner = 2\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	applied := make(chan *TOMLConfig, 8)
	w := LoadAndWatch(path, func(cfg *TOMLConfig) { applied <- cfg })
	defer w.Stop()
	waitApplied(t, applied, "existing")
}
