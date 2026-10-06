package agents

import (
	"context"
	"strings"
	"testing"
)

func TestCodexReadsLimitsAtStart(t *testing.T) {
	s := &limitsSink{}
	f := newFake(t, "codex_start_fail.jsonl")
	c, err := Lookup("codex").Start(context.Background(), StartOptions{Binary: f.bin, Cwd: f.dir, Env: f.env}, s)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = c.Close() })
	waitFor(t, "limits", func() bool { s.mu.Lock(); defer s.mu.Unlock(); return len(s.limits) == 1 })
	s.mu.Lock()
	l := s.limits[0]
	s.mu.Unlock()
	if w := window(t, l, "5h"); w.UsedPercent != 12 {
		t.Errorf("5h = %+v", w)
	}
	if w := window(t, l, "week"); w.UsedPercent != 3 {
		t.Errorf("week = %+v", w)
	}
	if !strings.Contains(f.stdin(), `"method":"account/rateLimits/read"`) {
		t.Errorf("stdin = %s", f.stdin())
	}
}

func TestCodexOneshotSkipsLimits(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "codex", "codex_oneshot.jsonl", StartOptions{Mode: "oneshot", Yolo: func() bool { return true }}, sink)
	_ = c.Send("hi", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	if strings.Contains(f.stdin(), "rateLimits") {
		t.Errorf("oneshot read limits: %s", f.stdin())
	}
}
