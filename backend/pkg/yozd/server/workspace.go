package server

import "yozakura/backend/pkg/yozd/ipc"

// switchWorkspace switches to workspace id. With keepCursor the pointer is
// put back where it was: Hyprland warps it to the middle of the target
// monitor when the workspace lives on another output, which is wrong for a
// switch made with the mouse (a click in the overview or the bar). Only
// compositors that can warp (ipc.CursorWarper) restore; elsewhere, or when
// the position cannot be read, it is a plain switch.
func switchWorkspace(c ipc.Compositor, id string, keepCursor bool) error {
	warper, canWarp := c.(ipc.CursorWarper)
	if !keepCursor || !canWarp {
		return c.SwitchWorkspace(id)
	}
	x, y, posErr := c.GetCursorPosition()
	if err := c.SwitchWorkspace(id); err != nil {
		return err
	}
	if posErr != nil {
		return nil
	}
	return warper.WarpCursor(x, y)
}
