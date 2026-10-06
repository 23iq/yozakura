.pragma library

// Whether the notch shows (NotchContent.reveal). Pure, tested in
// tests/notch-reveal.test.cjs. s = {
//   enabled               notch.enabled (off: only while it shows a view)
//   keepHidden            notch.keepHidden
//   sameEdge              the bar is on the notch's edge
//   hasWindows, fullscreen, barPinned, availableOnFullscreen
//   open                  a view is open in it (or a panel opened itself)
//   interacting           open, hovered, notifications, mic notice...
// }

// Notch and bar on different edges: hide with keepHidden or while windows
// are open; on the same edge: follow the bar's pin.
function shouldAutoHide(s) {
    if (!s.sameEdge)
        return !!s.keepHidden || !!s.hasWindows || !!s.fullscreen;
    return !s.barPinned || !!s.fullscreen;
}

function reveal(s) {
    // Fullscreen without the bar on fullscreen hard-hides the notch too
    if (s.fullscreen && !s.availableOnFullscreen)
        return false;
    if (s.enabled === false)
        return !!s.open;
    // keepHidden is ignored on the bar's edge, to stay in sync with it
    if (s.keepHidden && !s.sameEdge)
        return !!s.interacting;
    return !shouldAutoHide(s) || !!s.interacting;
}
