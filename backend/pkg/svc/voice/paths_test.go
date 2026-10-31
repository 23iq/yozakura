package voice

import (
	"os"
	"path/filepath"
	"testing"
)

func TestBackendReadsBuildInfo(t *testing.T) {
	for _, b := range []string{"cuda", "vulkan", "cpu"} {
		dir := t.TempDir()
		in := NewInstall(dir)
		if err := os.MkdirAll(in.Root, 0o755); err != nil {
			t.Fatal(err)
		}
		info := "backend=" + b + "\nversion=v1.9.4\n"
		if err := os.WriteFile(filepath.Join(in.Root, "BUILD_INFO"), []byte(info), 0o644); err != nil {
			t.Fatal(err)
		}
		if got := in.Backend(); got != b {
			t.Errorf("Backend() = %q, want %q", got, b)
		}
	}
}

func TestServerBinPrefersPackagedWhisper(t *testing.T) {
	i := Install{Root: "/data/whisper"}
	t.Setenv("YOZAKURA_WHISPER_BIN_DIR", "")
	if got := i.ServerBin(); got != "/data/whisper/bin/whisper-server" {
		t.Errorf("default = %q", got)
	}
	dir := t.TempDir()
	t.Setenv("YOZAKURA_WHISPER_BIN_DIR", dir)
	if got := i.ServerBin(); got != "/data/whisper/bin/whisper-server" {
		t.Errorf("env dir without the binary must fall back, got %q", got)
	}
	bin := filepath.Join(dir, "whisper-server")
	os.WriteFile(bin, []byte("#!/bin/sh\n"), 0o755)
	if got := i.ServerBin(); got != bin {
		t.Errorf("packaged = %q, want %q", got, bin)
	}
}
