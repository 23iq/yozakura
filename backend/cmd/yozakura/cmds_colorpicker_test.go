package main

import (
	"testing"

	"yozakura/backend/internal/screenshot"
)

// The colorpicker command runs its own screencopy: the compositor hint for
// frames whose size cannot tell their orientation must be wired in.
func TestColorPickerHasLogicalFramesHint(t *testing.T) {
	if screenshot.LogicalFramesHint == nil {
		t.Fatal("screenshot.LogicalFramesHint is nil in the yozakura binary")
	}
}
