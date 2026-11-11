package server

import "yozakura/backend/pkg/yozd/ipc"

// switchWorkspace switches to workspace id. With keepCursor the pointer
// stays where it is: Hyprland warps it to the middle of the target monitor
// when the workspace lives on another output, which is wrong for a pick
// made with the mouse in the overview (a single click). Only compositors
// that switch and place the pointer atomically (ipc.CursorKeepingSwitcher)
// keep it; elsewhere, or when the position cannot be read, it is a plain
// switch.
func switchWorkspace(c ipc.Compositor, id string, keepCursor bool) error {
	keeper, ok := c.(ipc.CursorKeepingSwitcher)
	if !keepCursor || !ok {
		return c.SwitchWorkspace(id)
	}
	x, y, err := c.GetCursorPosition()
	if err != nil {
		return c.SwitchWorkspace(id)
	}
	return keeper.SwitchWorkspaceKeepCursor(id, x, y)
}
