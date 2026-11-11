package capture

import (
	"sync"

	"yozakura/backend/internal/screenshot"
	"yozakura/backend/pkg/axmon"
)

// listMonitors is swapped in tests.
var listMonitors = axmon.List

var (
	logicalFramesMu    sync.Mutex
	logicalFramesKnown bool
	logicalFramesValue bool
)

func init() {
	screenshot.LogicalFramesHint = logicalFrames
}

// logicalFrames reports whether the compositor sends screencopy frames in
// logical orientation, as the compositor daemon tells per monitor
// (screencopy_logical). Asked once per process; a failed query (daemon not
// up yet) is not cached and reads as raw framebuffers.
func logicalFrames() bool {
	logicalFramesMu.Lock()
	defer logicalFramesMu.Unlock()
	if logicalFramesKnown {
		return logicalFramesValue
	}
	monitors, err := listMonitors()
	if err != nil {
		return false
	}
	value := false
	for _, m := range monitors {
		if m.ScreencopyLogical() {
			value = true
			break
		}
	}
	logicalFramesKnown, logicalFramesValue = true, value
	return value
}
