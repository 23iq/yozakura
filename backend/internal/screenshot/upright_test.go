package screenshot

import "testing"

// withLogicalHint swaps the compositor fallback for the duration of a test.
func withLogicalHint(t *testing.T, hint func() bool) {
	t.Helper()
	prev := LogicalFramesHint
	LogicalFramesHint = hint
	t.Cleanup(func() { LogicalFramesHint = prev })
}

// rawResult is a capture of an output whose current mode is modeW x modeH,
// delivered as a bufW x bufH frame (pixel (x,y) has r=x, g=y).
func rawResult(t *testing.T, transform, modeW, modeH int32, bufW, bufH int) *CaptureResult {
	t.Helper()
	return &CaptureResult{
		Buffer:    newTestBuffer(t, bufW, bufH),
		Region:    Region{X: 10, Y: 20, Width: modeW, Height: modeH},
		Format:    uint32(FormatARGB8888),
		Transform: transform,
	}
}

func pixelRG(b *ShmBuffer, x, y int) (r, g byte) {
	off := y*b.Stride + x*4
	return b.Data()[off+2], b.Data()[off+1]
}

func uprightOK(t *testing.T, in *CaptureResult) *CaptureResult {
	t.Helper()
	out, err := Upright(in)
	if err != nil {
		t.Fatalf("upright: %v", err)
	}
	t.Cleanup(func() { out.Buffer.Close() })
	return out
}

func assertDims(t *testing.T, r *CaptureResult, w, h int) {
	t.Helper()
	if r.Buffer.Width != w || r.Buffer.Height != h {
		t.Fatalf("buffer %dx%d, want %dx%d", r.Buffer.Width, r.Buffer.Height, w, h)
	}
	if int(r.Region.Width) != w || int(r.Region.Height) != h {
		t.Fatalf("region %dx%d disagrees with buffer %dx%d", r.Region.Width, r.Region.Height, w, h)
	}
	if r.Region.X != 10 || r.Region.Y != 20 {
		t.Fatalf("region origin moved to %d,%d", r.Region.X, r.Region.Y)
	}
}

// assertUntouched checks every pixel still holds its source coordinates.
func assertUntouched(t *testing.T, r *CaptureResult) {
	t.Helper()
	for y := 0; y < r.Buffer.Height; y++ {
		for x := 0; x < r.Buffer.Width; x++ {
			if gr, gg := pixelRG(r.Buffer, x, y); gr != byte(x) || gg != byte(y) {
				t.Fatalf("pixel (%d,%d) = r%d g%d, frame was rotated", x, y, gr, gg)
			}
		}
	}
}

// A raw (mode-sized) framebuffer of a 90° output is still rotated upright:
// wlroots, niri and Hyprland <= 0.56.
func TestUprightRotatesRawFrame90(t *testing.T) {
	withLogicalHint(t, func() bool { return true })
	out := uprightOK(t, rawResult(t, Transform90, 6, 4, 6, 4))
	assertDims(t, out, 4, 6)
	for y := 0; y < 6; y++ {
		for x := 0; x < 4; x++ {
			// inverse of 90 is 270: (sx,sy) -> (H-1-sy, sx)
			if r, g := pixelRG(out.Buffer, x, y); r != byte(y) || g != byte(3-x) {
				t.Fatalf("pixel (%d,%d) = r%d g%d, want r%d g%d", x, y, r, g, y, 3-x)
			}
		}
	}
}

func TestUprightRotatesRawFrame270(t *testing.T) {
	out := uprightOK(t, rawResult(t, Transform270, 6, 4, 6, 4))
	assertDims(t, out, 4, 6)
	for y := 0; y < 6; y++ {
		for x := 0; x < 4; x++ {
			// inverse of 270 is 90: (sx,sy) -> (sy, W-1-sx)
			if r, g := pixelRG(out.Buffer, x, y); r != byte(5-y) || g != byte(x) {
				t.Fatalf("pixel (%d,%d) = r%d g%d, want r%d g%d", x, y, r, g, 5-y, x)
			}
		}
	}
}

// Hyprland >= 0.57 sends the frame already in logical orientation: the
// buffer has the mode's sides swapped and must not be rotated again.
func TestUprightKeepsLogicalFrameRotated(t *testing.T) {
	withLogicalHint(t, func() bool { return false })
	for _, tr := range []int32{Transform90, Transform270, TransformFlipped90, TransformFlipped270} {
		out := uprightOK(t, rawResult(t, tr, 6, 4, 4, 6))
		assertDims(t, out, 4, 6)
		assertUntouched(t, out)
	}
}

func TestUprightRotatesRawFrameFlipped90(t *testing.T) {
	for _, tr := range []int32{TransformFlipped90, TransformFlipped270} {
		out := uprightOK(t, rawResult(t, tr, 6, 4, 6, 4))
		assertDims(t, out, 4, 6)
	}
}

// The y-invert flip still happens when the rotation is skipped.
func TestUprightLogicalFrameStillFlipsInverted(t *testing.T) {
	in := rawResult(t, Transform90, 6, 4, 4, 6)
	in.YInverted = true
	out := uprightOK(t, in)
	assertDims(t, out, 4, 6)
	if out.YInverted {
		t.Fatal("YInverted should be cleared")
	}
	if r, g := pixelRG(out.Buffer, 1, 0); r != 1 || g != 5 {
		t.Fatalf("pixel (1,0) = r%d g%d, want the last source row (r1 g5)", r, g)
	}
}

// 180° frames have the same size in both orientations: only the
// compositor hint can tell them apart.
func TestUpright180FollowsHint(t *testing.T) {
	withLogicalHint(t, func() bool { return true })
	out := uprightOK(t, rawResult(t, Transform180, 6, 4, 6, 4))
	assertDims(t, out, 6, 4)
	assertUntouched(t, out)

	withLogicalHint(t, func() bool { return false })
	out = uprightOK(t, rawResult(t, Transform180, 6, 4, 6, 4))
	assertDims(t, out, 6, 4)
	if r, g := pixelRG(out.Buffer, 0, 0); r != 5 || g != 3 {
		t.Fatalf("pixel (0,0) = r%d g%d, want flipped r5 g3", r, g)
	}

	withLogicalHint(t, nil)
	out = uprightOK(t, rawResult(t, Transform180, 6, 4, 6, 4))
	if r, g := pixelRG(out.Buffer, 0, 0); r != 5 || g != 3 {
		t.Fatalf("no hint: pixel (0,0) = r%d g%d, want flipped r5 g3", r, g)
	}
}

// A square mode cannot be told apart by size either.
func TestUprightSquareModeFollowsHint(t *testing.T) {
	withLogicalHint(t, func() bool { return true })
	out := uprightOK(t, rawResult(t, Transform90, 5, 5, 5, 5))
	assertDims(t, out, 5, 5)
	assertUntouched(t, out)

	withLogicalHint(t, func() bool { return false })
	out = uprightOK(t, rawResult(t, Transform90, 5, 5, 5, 5))
	if r, g := pixelRG(out.Buffer, 0, 0); r != 0 || g != 4 {
		t.Fatalf("pixel (0,0) = r%d g%d, want rotated r0 g4", r, g)
	}
}

// The hint is not consulted when the frame size already decides.
func TestUprightHintOnlyForAmbiguousFrames(t *testing.T) {
	called := 0
	withLogicalHint(t, func() bool { called++; return true })
	uprightOK(t, rawResult(t, Transform90, 6, 4, 6, 4))
	uprightOK(t, rawResult(t, Transform90, 6, 4, 4, 6))
	uprightOK(t, rawResult(t, TransformNormal, 6, 4, 6, 4))
	if called != 0 {
		t.Fatalf("hint called %d times", called)
	}
}
