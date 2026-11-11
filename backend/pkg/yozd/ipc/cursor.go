package ipc

// CursorKeepingSwitcher is implemented by compositors that can switch
// workspace and put the pointer at layout (global logical) coordinates in
// one atomic request (Hyprland: one [[BATCH]] of the workspace switch and
// movecursor / hl.dsp.cursor.move). Atomic, so the pointer never shows up
// at the compositor's warp target in between (hover, enter, focus there).
type CursorKeepingSwitcher interface {
	SwitchWorkspaceKeepCursor(id string, x, y int) error
}
