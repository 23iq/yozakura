package hyprland

import (
	"fmt"
	"strings"
)

// SwitchWorkspaceKeepCursor switches to workspace id and puts the pointer
// at x,y in one [[BATCH]] request (ipc.CursorKeepingSwitcher): Hyprland
// warps the pointer to the middle of the target monitor when the workspace
// lives on another output, and two separate requests would let it sit
// there for a frame.
func (h *Hyprland) SwitchWorkspaceKeepCursor(id string, x, y int) error {
	var cmds []string
	if h.supportsLuaDispatchers() {
		cmds = []string{
			fmt.Sprintf("dispatch hl.dsp.focus({ workspace = %q })", id),
			fmt.Sprintf("dispatch hl.dsp.cursor.move({ x = %d, y = %d })", x, y),
		}
	} else {
		cmds = []string{
			fmt.Sprintf("dispatch workspace %s", id),
			fmt.Sprintf("dispatch movecursor %d %d", x, y),
		}
	}
	resp, err := h.dispatch("[[BATCH]]" + strings.Join(cmds, ";"))
	if err != nil {
		return err
	}
	return checkBatchReply(cmds, resp)
}
