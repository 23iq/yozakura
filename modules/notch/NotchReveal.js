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

// Notch and bar on different edges: hide while windows are open (keepHidden
// is handled in reveal()); on the same edge: follow the bar's pin.
function shouldAutoHide(s) {
    if (!s.sameEdge)
        return !!s.hasWindows || !!s.fullscreen;
    return !s.barPinned || !!s.fullscreen;
}

function reveal(s) {
    // Fullscreen without the bar on fullscreen hard-hides the notch too
    if (s.fullscreen && !s.availableOnFullscreen)
        return false;
    if (s.enabled === false)
        return !!s.open;
    // keepHidden hides the notch on every edge, the bar's own included (the
    // bar keeps its place in its pin): only interaction shows it
    if (s.keepHidden)
        return !!s.interacting;
    return !shouldAutoHide(s) || !!s.interacting;
}
