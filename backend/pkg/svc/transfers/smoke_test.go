package transfers

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

// Real-system smoke test (no fakes): YOZAKURA_SMOKE=1 go test -run Smoke -v
func TestSmokeRealSources(t *testing.T) {
	if os.Getenv("YOZAKURA_SMOKE") != "1" {
		t.Skip("set YOZAKURA_SMOKE=1")
	}
	dir := t.TempDir()
	var mu sync.Mutex
	seen := map[string]Transfer{}
	run := func(src Source, opts Options) context.CancelFunc {
		ctx, cancel := context.WithCancel(context.Background())
		go src.Run(ctx, &Env{Options: opts, update: func(items []Transfer) {
			mu.Lock()
			for _, it := range items {
				seen[it.Key+"|"+it.State] = it
			}
			mu.Unlock()
		}})
		return cancel
	}
	stopB := run(newBrowserSource(), Options{DownloadDir: dir})
	defer stopB()
	stopT := run(newProcSource(terminalTools, terminalPick), Options{})
	defer stopT()

	// A browser-style .part file growing at ~2 MB/s
	part := filepath.Join(dir, "smoke.bin.part")
	writer := exec.Command("python3", "-c", `
import sys, time
with open(sys.argv[1], "wb") as f:
    for _ in range(8):
        f.write(b"\0" * (1 << 20)); f.flush(); time.sleep(0.5)
`, part)
	must(t, writer.Start())
	// curl writing a local "download"
	out := filepath.Join(dir, "curl-smoke.bin")
	// --range bounds the file (--limit-rate does not apply to file://)
	curl := exec.Command("curl", "-s", "--limit-rate", "2M", "--range", "0-8388607", "-o", out, "file:///dev/zero")
	if err := curl.Start(); err != nil {
		t.Logf("curl unavailable: %v", err)
	}
	writer.Wait()
	must(t, os.Rename(part, filepath.Join(dir, "smoke.bin")))
	if curl.Process != nil {
		curl.Wait()
	}
	time.Sleep(2500 * time.Millisecond)
	mu.Lock()
	defer mu.Unlock()
	for k, it := range seen {
		t.Logf("%s: app=%s title=%s processed=%d total=%d rate=%.0f state=%s", k, it.App, it.Title, it.Processed, it.Total, it.Rate, it.State)
	}
	if _, ok := seen["smoke.bin.part|"+StateDone]; !ok {
		t.Error("browser download never reported done")
	}
}
