package colorpicker

import (
	"testing"

	"yozakura/backend/internal/screenshot"
)

// withLogicalHint swaps the compositor fallback for the duration of a test.
func withLogicalHint(t *testing.T, hint func() bool) {
	t.Helper()
	prev := screenshot.LogicalFramesHint
	screenshot.LogicalFramesHint = hint
	t.Cleanup(func() { screenshot.LogicalFramesHint = prev })
}

// output6x4 is an output whose current mode is 6x4 (unrotated, as
// wl_output.mode reports it) under the given wl_output transform.
func output6x4(transform int32) *Output {
	return &Output{width: 6, height: 4, transform: transform}
}

// A raw (mode-sized) framebuffer of a rotated output is rotated upright:
// wlroots, niri and Hyprland <= 0.56.
func TestUprightTransformRotatesRawFrame(t *testing.T) {
	withLogicalHint(t, func() bool { return true })
	for _, tr := range []int32{Transform90, Transform270, TransformFlipped90, TransformFlipped270} {
		if got := output6x4(tr).uprightTransform(6, 4); got != InverseTransform(tr) {
			t.Errorf("transform %d, raw 6x4 frame: got %d, want %d", tr, got, InverseTransform(tr))
		}
	}
}

// Hyprland >= 0.57 sends the frame already in logical orientation: the
// buffer has the mode's sides swapped and must not be rotated again.
func TestUprightTransformKeepsLogicalFrame(t *testing.T) {
	withLogicalHint(t, func() bool { return false })
	for _, tr := range []int32{Transform90, Transform270, TransformFlipped90, TransformFlipped270} {
		if got := output6x4(tr).uprightTransform(4, 6); got != TransformNormal {
			t.Errorf("transform %d, logical 4x6 frame: got %d, want untouched", tr, got)
		}
	}
}

// 180° frames have the same size in both orientations: only the
// compositor hint can tell them apart; no hint means a raw framebuffer.
func TestUprightTransform180FollowsHint(t *testing.T) {
	cases := []struct {
		name string
		hint func() bool
		want int32
	}{
		{"logical", func() bool { return true }, TransformNormal},
		{"raw", func() bool { return false }, Transform180},
		{"no hint", nil, Transform180},
	}
	for _, c := range cases {
		withLogicalHint(t, c.hint)
		if got := output6x4(Transform180).uprightTransform(6, 4); got != c.want {
			t.Errorf("180, %s: got %d, want %d", c.name, got, c.want)
		}
	}
}

func TestUprightTransformNormal(t *testing.T) {
	withLogicalHint(t, func() bool { t.Fatal("hint consulted for a normal output"); return false })
	if got := output6x4(TransformNormal).uprightTransform(6, 4); got != TransformNormal {
		t.Fatalf("got %d, want untouched", got)
	}
}

// The screen buffer the picker keeps is logical size x scale either way,
// so the pointer -> buffer scale stays consistent.
func TestUprightBufferIsLogicalSized(t *testing.T) {
	withLogicalHint(t, nil)
	for _, size := range [][2]int{{6, 4}, {4, 6}} {
		buf, err := CreateShmBuffer(size[0], size[1], size[0]*4)
		if err != nil {
			t.Fatalf("create buffer: %v", err)
		}
		out, err := output6x4(Transform90).upright(buf)
		if err != nil {
			t.Fatalf("upright: %v", err)
		}
		if out.Width != 4 || out.Height != 6 {
			t.Errorf("%dx%d frame -> %dx%d, want 4x6", size[0], size[1], out.Width, out.Height)
		}
		if out != buf {
			out.Close()
		}
		buf.Close()
	}
}
