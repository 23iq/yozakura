.pragma library

// Whether the dock shows and whether its hitbox takes input
// (DockContent). Pure, tested in tests/dock-reveal.test.cjs. s = {
//   preview               a settings preview (always shown)
//   fullscreen            a fullscreen window covers this screen
//   availableOnFullscreen dock.availableOnFullscreen
//   hoverToReveal         dock.hoverToReveal
//   keepHidden            dock.keepHidden
//   pinned                the dock's pin
//   hovered               the pointer is on the dock's hitbox
//   hasWindows            windows on the active workspace
// }

// Over a fullscreen window the dock can only come back by hover, and only
// with dock.availableOnFullscreen and dock.hoverToReveal on.
function fullscreenBlocked(s) {
    return !s.preview && !!s.fullscreen && !(s.availableOnFullscreen && s.hoverToReveal);
}

function reveal(s) {
    if (s.preview)
        return true;
    if (s.fullscreen)
        return !fullscreenBlocked(s) && !!s.hovered;
    const hover = !!s.hoverToReveal && !!s.hovered;
    // keepHidden overrides the pin and an empty workspace
    if (s.keepHidden)
        return hover;
    return !!s.pinned || hover || !s.hasWindows;
}

// The hitbox stays in the input mask unless the dock cannot show: the
// unified panel is an Overlay surface, an edge strip under a fullscreen
// window would take the pointer from the fullscreen client.
function takesInput(s) {
    return !fullscreenBlocked(s);
}
