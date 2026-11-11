package hyprland

import "fmt"

// WarpCursor moves the pointer to layout coordinates (ipc.CursorWarper).
func (h *Hyprland) WarpCursor(x, y int) error {
	_, err := h.dispatchVersioned(
		fmt.Sprintf("movecursor %d %d", x, y),
		fmt.Sprintf("hl.dsp.cursor.move({ x = %d, y = %d })", x, y),
	)
	return err
}
