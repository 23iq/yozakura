package ipc

// CursorWarper is implemented by compositors that can move the pointer to
// layout (global logical) coordinates (Hyprland: movecursor /
// hl.dsp.cursor.move). Used to put the pointer back where it was after an
// action the compositor follows with a warp of its own.
type CursorWarper interface {
	WarpCursor(x, y int) error
}
