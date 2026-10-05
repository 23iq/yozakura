.pragma library

// Which layers of a workspace slot are shown: its number label, the
// placeholder dot, and the icon of its most recently focused window.
// `ws` is Config.workspaces (showNumbers, alwaysShowNumbers, showAppIcons);
// `hasWindow` tells whether the workspace has a window to take the icon from.

function numberVisible(ws, hasWindow) {
    return !!(ws.alwaysShowNumbers || (ws.showNumbers && (!ws.showAppIcons || !hasWindow)));
}

function dotOpacity(ws, hasWindow, active, occupied) {
    if (ws.showNumbers || ws.alwaysShowNumbers || (ws.showAppIcons && hasWindow))
        return 0;
    return active || occupied ? 1 : 0.5;
}

// The icon fills the slot unless numbers are forced, then it shrinks into
// a corner badge next to the number.
function iconFullSize(ws) {
    return !!(!ws.alwaysShowNumbers && ws.showAppIcons);
}

function iconOpacity(ws, hasWindow, shrinkedOpacity) {
    if (!ws.showAppIcons || !hasWindow)
        return 0;
    return ws.alwaysShowNumbers ? shrinkedOpacity : 1;
}
