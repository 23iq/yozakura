package capture

import (
	"errors"
	"testing"

	"yozakura/backend/internal/screenshot"
	"yozakura/backend/pkg/axmon"
)

func stubMonitorList(t *testing.T, fn func() ([]axmon.Monitor, error)) {
	t.Helper()
	prev := listMonitors
	listMonitors = fn
	resetLogicalFrames()
	t.Cleanup(func() {
		listMonitors = prev
		resetLogicalFrames()
	})
}

func TestUprightUsesDaemonHint(t *testing.T) {
	if screenshot.LogicalFramesHint == nil {
		t.Fatal("capture must install the screencopy orientation hint")
	}
}

// The daemon is asked once; a failed query is retried, a result is kept.
func TestLogicalFramesCached(t *testing.T) {
	calls := 0
	fail := true
	stubMonitorList(t, func() ([]axmon.Monitor, error) {
		calls++
		if fail {
			return nil, errors.New("daemon not up")
		}
		return []axmon.Monitor{
			{Name: "DP-1", Metadata: map[string]interface{}{"screencopy_logical": true}},
		}, nil
	})

	if logicalFrames() {
		t.Fatal("a failed query must not report logical frames")
	}
	fail = false
	for i := 0; i < 3; i++ {
		if !logicalFrames() {
			t.Fatal("expected logical frames from the daemon")
		}
	}
	if calls != 2 {
		t.Fatalf("daemon queried %d times, want 2 (failure retried, then cached)", calls)
	}
}

func TestLogicalFramesFalseWithoutFlag(t *testing.T) {
	stubMonitorList(t, func() ([]axmon.Monitor, error) {
		return []axmon.Monitor{{Name: "eDP-1", Metadata: map[string]interface{}{"x": float64(0)}}}, nil
	})
	if logicalFrames() {
		t.Fatal("no screencopy_logical flag means raw framebuffers")
	}
}

func resetLogicalFrames() {
	logicalFramesMu.Lock()
	logicalFramesKnown, logicalFramesValue = false, false
	logicalFramesMu.Unlock()
}
