package colorpicker

import "yozakura/backend/internal/screenshot"

// uprightTransform returns the transform that turns a frameW x frameH
// screencopy frame of the output upright (TransformNormal: leave it as is).
// Hyprland >= 0.57 sends frames already in logical orientation while
// wl_output keeps reporting the monitor transform, so the decision is the
// screenshot one (frame size against the unrotated mode, then the
// compositor hint screenshot.LogicalFramesHint).
func (o *Output) uprightTransform(frameW, frameH int) int32 {
	if screenshot.FrameInLogicalOrientation(o.transform, o.width, o.height, frameW, frameH) {
		return TransformNormal
	}
	return InverseTransform(o.transform)
}

// upright returns buf turned upright, or buf itself when it already is.
// The result is logical size x scale in either case.
func (o *Output) upright(buf *ShmBuffer) (*ShmBuffer, error) {
	tr := o.uprightTransform(buf.Width, buf.Height)
	if tr == TransformNormal {
		return buf, nil
	}
	return buf.ApplyTransform(tr)
}
