package main

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/brand"
)

func TestDefaultSocketPathPrefersRuntimeDir(t *testing.T) {
	dir := t.TempDir()
	t.Setenv(brand.DaemonEnv("SOCKET"), "")
	t.Setenv("XDG_RUNTIME_DIR", dir)
	if got := defaultSocketPath(); got != filepath.Join(dir, brand.Daemon+".sock") {
		t.Fatalf("want runtime-dir path, got %q", got)
	}
}

func TestDefaultSocketPathFallsBackToTmp(t *testing.T) {
	t.Setenv(brand.DaemonEnv("SOCKET"), "")
	t.Setenv("XDG_RUNTIME_DIR", "")
	want := fmt.Sprintf("/tmp/%s-%d.sock", brand.Daemon, os.Getuid())
	// A running daemon's socket in /run/user/<uid> wins (cleared-env parents).
	if live := fmt.Sprintf("/run/user/%d/%s.sock", os.Getuid(), brand.Daemon); fileExists(live) {
		want = live
	}
	if got := defaultSocketPath(); got != want {
		t.Fatalf("want %q, got %q", want, got)
	}
}

func TestDefaultSocketPathOverride(t *testing.T) {
	t.Setenv(brand.DaemonEnv("SOCKET"), "/custom/daemon.sock")
	if got := defaultSocketPath(); got != "/custom/daemon.sock" {
		t.Fatalf("want override honored, got %q", got)
	}
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
