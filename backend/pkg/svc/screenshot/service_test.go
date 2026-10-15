package screenshot

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestClipboardUnresponsiveOwner(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "wl-copy")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\nexec /bin/sleep 6\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	image := filepath.Join(dir, "test.png")
	if err := os.WriteFile(image, []byte("png fixture"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	start := time.Now()
	err := copyFileToClipboard(image)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("clipboard must report its timeout, got %v", err)
	}
	if elapsed := time.Since(start); elapsed > 4*time.Second {
		t.Fatalf("clipboard stalled screenshot response for %s", elapsed)
	}
}
