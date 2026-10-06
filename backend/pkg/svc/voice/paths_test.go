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
