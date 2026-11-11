// Portions Copyright (c) 2025 Avenge Media LLC
// Licensed under the MIT License. Derived from DankMaterialShell.

package screenshot

// LogicalFramesHint reports whether the running compositor sends
// screencopy frames in logical orientation (Hyprland >= 0.57, 901881c9f
// "render: always render in normal transform"). It is consulted only when
// the frame size cannot tell (180° and flipped transforms, square modes);
// nil means "raw framebuffer", the wlroots/niri behaviour. Callers set it
// to a cached detector: Upright runs once per frame.
var LogicalFramesHint func() bool

// FrameInLogicalOrientation reports whether a frame of frameW x frameH
// captured from an output whose current mode is modeW x modeH (unrotated,
// as wl_output.mode reports it) and whose wl_output transform is transform
// already reads upright, so the inverse transform must not be applied.
// wl_output keeps reporting the monitor transform even when the compositor
// rotated the frame itself.
func FrameInLogicalOrientation(transform, modeW, modeH int32, frameW, frameH int) bool {
	switch transform {
	case TransformNormal:
		return true
	case Transform90, Transform270, TransformFlipped90, TransformFlipped270:
		if modeW != modeH && modeW > 0 && modeH > 0 {
			return frameW == int(modeH) && frameH == int(modeW)
		}
	}
	return LogicalFramesHint != nil && LogicalFramesHint()
}
