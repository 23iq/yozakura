.pragma library

// A shell module (launcher, dashboard, ...) holds exclusive keyboard focus
// and a focus grab while open. Switching workspaces under it (super+2) leaves
// the compositor's "last focused window" on the old workspace, and Hyprland
// jumps back there when the module closes and focus is restored. So an open
// module closes as soon as the workspace on its screen changes: focus is
// handed back while the new workspace is already active.

// Modules that switch workspaces themselves while open stay open.
var KEEP_OPEN = ["overview"];

// Where the open module is shown: {screen, workspace} (workspace "" when
// unknown, e.g. before the first compositor state).
function place(screen, monitor) {
    var ws = monitor && monitor.activeWorkspace ? monitor.activeWorkspace : null;
    var id = ws ? (ws.id || ws.name || "") : "";
    return {
        screen: screen || "",
        workspace: id === "" ? "" : String(id)
    };
}

// True when `module` must close because its screen moved to another
// workspace between `prev` and `next` (both from place()). A screen change
// is the module moving with the focused monitor, never a dismiss.
function shouldDismiss(prev, next, module) {
    if (!module || KEEP_OPEN.indexOf(module) !== -1)
        return false;
    if (!prev || !next || !prev.screen || prev.screen !== next.screen)
        return false;
    if (!prev.workspace || !next.workspace)
        return false;
    return prev.workspace !== next.workspace;
}
