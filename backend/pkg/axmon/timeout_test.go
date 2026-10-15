package axmon

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/paths"
)

func TestListUnresponsiveDaemon(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "monitor-test")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\nexec /bin/sleep 6\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv(paths.DaemonBinEnv, bin)
	monitors, err := List()
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("unresponsive monitor lookup must report its deadline, got %v (monitors %v)", err, monitors)
	}
}
