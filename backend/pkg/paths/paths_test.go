package paths

import (
	"os"
	"path/filepath"
	"testing"
)

func TestUserDirParsesXdgFile(t *testing.T) {
	home := t.TempDir()
	os.MkdirAll(filepath.Join(home, ".config"), 0o755)
	os.WriteFile(filepath.Join(home, ".config", "user-dirs.dirs"), []byte(
		"# comment\n"+
			"XDG_PICTURES_DIR=\"$HOME/Imágenes\"\n"+
			`XDG_VIDEOS_DIR="/mnt/shared/clips"`+"\n",
	), 0o644)

	t.Setenv("HOME", home)
	t.Setenv("XDG_PICTURES_DIR", "")
	t.Setenv("XDG_VIDEOS_DIR", "")

	p := New()
	if got := p.PicturesDir(); got != filepath.Join(home, "Imágenes") {
		t.Fatalf("PicturesDir = %q", got)
	}
	if got := p.VideosDir(); got != "/mnt/shared/clips" {
		t.Fatalf("VideosDir should honor absolute paths, got %q", got)
	}
}

func TestUserDirFallsBack(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_PICTURES_DIR", "")

	p := New()
	if got := p.PicturesDir(); got != filepath.Join(home, "Pictures") {
		t.Fatalf("PicturesDir fallback = %q", got)
	}
}

func TestLauncherPrefersExecutableEnv(t *testing.T) {
	dir := t.TempDir()
	launcher := filepath.Join(dir, "yozakura")
	os.WriteFile(launcher, []byte("#!/bin/sh\n"), 0o755)

	t.Setenv(LauncherEnv, launcher)
	if got := Launcher("/nix/store/x/bin/yozakura"); got != launcher {
		t.Errorf("Launcher() = %q, want %q", got, launcher)
	}
	t.Setenv(LauncherEnv, filepath.Join(dir, "missing"))
	if got := Launcher("/fallback"); got != "/fallback" {
		t.Errorf("missing launcher must fall back, got %q", got)
	}
	t.Setenv(LauncherEnv, "")
	if got := Launcher("/fallback"); got != "/fallback" {
		t.Errorf("unset launcher must fall back, got %q", got)
	}
}
