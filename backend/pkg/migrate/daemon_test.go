package migrate

import (
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
)

func TestMigrateDaemonFiles(t *testing.T) {
	root := t.TempDir()
	p := paths.Paths{DataDir: filepath.Join(root, "data")}
	cfg := filepath.Join(root, "config")
	legacyToml := filepath.Join(p.DataDir, brand.LegacyDaemon+".toml")
	legacyBright := filepath.Join(cfg, brand.LegacyDaemon, "brightness.tsv")
	for path, body := range map[string]string{legacyToml: "[target]\n", legacyBright: "eDP-1\t40\n"} {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	moves := DaemonMoves(p, cfg)
	done, err := MigrateDaemonFiles(moves)
	if err != nil || len(done) != 2 {
		t.Fatalf("first run: done=%v err=%v", done, err)
	}
	if got := readFile(t, p.DaemonToml()); got != "[target]\n" {
		t.Fatalf("config not moved: %q", got)
	}
	if got := readFile(t, filepath.Join(cfg, brand.Daemon, "brightness.tsv")); got != "eDP-1\t40\n" {
		t.Fatalf("brightness not moved: %q", got)
	}
	if exists(legacyToml) || exists(legacyBright) {
		t.Fatal("legacy files must be gone after the rename")
	}

	// Second run is a no-op.
	if done, err := MigrateDaemonFiles(moves); err != nil || len(done) != 0 {
		t.Fatalf("second run: done=%v err=%v", done, err)
	}

	// An existing target always wins over a reappearing legacy file.
	if err := os.WriteFile(legacyToml, []byte("stale"), 0o644); err != nil {
		t.Fatal(err)
	}
	if done, err := MigrateDaemonFiles(moves); err != nil || len(done) != 0 {
		t.Fatalf("target exists: done=%v err=%v", done, err)
	}
	if got := readFile(t, p.DaemonToml()); got != "[target]\n" {
		t.Fatalf("target overwritten: %q", got)
	}
}

func TestDaemonMovesWithoutUserConfigDir(t *testing.T) {
	if got := DaemonMoves(paths.Paths{DataDir: "/d"}, ""); len(got) != 1 {
		t.Fatalf("want only the config move, got %v", got)
	}
}
