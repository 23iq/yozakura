package main

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/proc"
	convertsvc "yozakura/backend/pkg/svc/convert"
)

// SIGINT / SIGTERM cancel the jobs and clean up before the command exits:
// no result, no work directory left anywhere.
func TestConvertCLIInterrupt(t *testing.T) {
	tools := conv.DetectTools(nil)
	if !tools.Has(conv.EngineFFmpeg) {
		t.Skip("ffmpeg not installed")
	}
	dir, cache := t.TempDir(), t.TempDir()
	wav := filepath.Join(dir, "long.wav")
	if _, err := proc.Run(context.Background(), tools.Prog(conv.EngineFFmpeg), "-hide_banner", "-loglevel", "error", "-nostdin",
		"-f", "lavfi", "-i", "sine=duration=900", wav); err != nil {
		t.Fatal(err)
	}
	s := convertsvc.New(convertsvc.Options{Detect: func() *conv.Tools { return tools }, CacheDir: cache, Home: t.TempDir()})
	stop := make(chan struct{})
	time.AfterFunc(300*time.Millisecond, func() { close(stop) })
	var out, errOut bytes.Buffer
	start := time.Now()
	env := convertEnv{svc: s, tick: 10 * time.Millisecond, tools: s.Tools, interrupted: stop}
	code := runConvert([]string{wav, "--to", "flac"}, env, &out, &errOut)
	if code != 130 || time.Since(start) > 20*time.Second {
		t.Fatalf("exit %d after %s: %s", code, time.Since(start), errOut.String())
	}
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if e.Name() != "long.wav" {
			t.Errorf("left %s next to the source", e.Name())
		}
	}
	if work, _ := os.ReadDir(filepath.Join(cache, "work")); len(work) != 0 {
		t.Errorf("left %d work dirs in the cache", len(work))
	}
}
