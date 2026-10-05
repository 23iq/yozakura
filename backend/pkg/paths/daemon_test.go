package paths

import (
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/brand"
)

func TestDaemonBinaryPrefersEnvThenPath(t *testing.T) {
	t.Setenv(DaemonBinEnv, "/opt/custom/"+brand.Daemon)
	if got := DaemonBinary(); got != "/opt/custom/"+brand.Daemon {
		t.Fatalf("env override: got %q", got)
	}
	t.Setenv(DaemonBinEnv, "")
	bin := t.TempDir()
	fake := filepath.Join(bin, brand.Daemon)
	if err := os.WriteFile(fake, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	if got := DaemonBinary(); got != fake {
		t.Fatalf("PATH lookup: got %q want %q", got, fake)
	}
	t.Setenv("PATH", t.TempDir())
	if got := DaemonBinary(); got != brand.Daemon {
		t.Fatalf("fallback: got %q", got)
	}
}

func TestDaemonToml(t *testing.T) {
	p := &Paths{DataDir: "/data"}
	if got := p.DaemonToml(); got != "/data/"+brand.DaemonConfigFile() {
		t.Fatalf("got %q", got)
	}
}
