package main

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func TestDetectLegacyDaemon(t *testing.T) {
	dir := t.TempDir()
	if _, running := detectLegacyDaemon(dir); running {
		t.Fatal("no pid file must mean not running")
	}
	pidFile := filepath.Join(dir, "ambxst-qs.pid")
	os.WriteFile(pidFile, []byte(strconv.Itoa(os.Getpid())), 0o644)
	if pid, running := detectLegacyDaemon(dir); !running || pid != os.Getpid() {
		t.Fatalf("live pid: got %d %v", pid, running)
	}
	os.WriteFile(pidFile, []byte("999999999"), 0o644)
	if _, running := detectLegacyDaemon(dir); running {
		t.Fatal("stale pid must mean not running")
	}
}
