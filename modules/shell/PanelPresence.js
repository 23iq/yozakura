.pragma library

// Whether a screen's unified panel window must stay mapped
// (performance.hidePanelInFullscreen, UnifiedShellPanel / PanelPresence).
// Without a fullscreen window it always is. Under one, the panel may unmap
// (not draw transparent: a mapped Overlay surface keeps the compositor
// from scanning the fullscreen client out directly) only while nothing in
// it is on screen or has to react to the pointer. Every reason below is
// one of the panel's children or input regions; unit tested in
// tests/panel-presence.test.cjs. s = {
//   fullscreen        a fullscreen window on this screen
//   barRevealOnHover  bar.availableOnFullscreen with a bar or notch here:
//                     their edge strip must stay hoverable (the panel's
//                     input mask), so the panel never unmaps
//   dockRevealOnHover the dock is here, dock.availableOnFullscreen and
//                     dock.hoverToReveal: same, for the dock's edge
//   barShown          a bar panel is revealed (BarContent.reveal)
//   barPopupOpen      a popup of a bar of this screen is open (BarPopup is
//                     anchored to this window)
//   notchShown        the notch is revealed (NotchContent.reveal)
//   notchOpen         a view or a modal panel is open in the notch
//   dockShown         the dock is revealed
//   activitiesShown   live activity islands are out
//   notifications     notification popups for this screen (notch, corner
//                     toasts or strips)
//   stripsOpen        an opened notification strip (takes the keyboard)
//   cornerPills       re-homed corner pills (bar or notch off) show
//   moduleOpen        a view is open on this screen (launcher, dashboard,
//                     overview, power menu, tools, presets, ...)
//   osdInPanel        the volume / brightness OSD shows in the bar or the
//                     notch (bar-inline, island)
//   focusGrab         a focus grab is active (click-outside goes through
//                     this window's full-screen backdrop)
//   frameDrawn        the frame is drawn in this panel with some thickness
//                     (restored around a revealed panel, a pinned sidebar)
// }

var REASONS = ["barRevealOnHover", "dockRevealOnHover", "barShown", "barPopupOpen", "notchShown", "notchOpen", "dockShown", "activitiesShown", "notifications", "stripsOpen", "cornerPills", "moduleOpen", "osdInPanel", "focusGrab", "frameDrawn"];

// The reasons that hold now (["noFullscreen"] without a fullscreen window)
function reasons(s) {
    var st = s || {};
    if (!st.fullscreen)
        return ["noFullscreen"];
    var out = [];
    for (var i = 0; i < REASONS.length; i++) {
        if (st[REASONS[i]])
            out.push(REASONS[i]);
    }
    return out;
}

function keepMapped(s) {
    return reasons(s).length > 0;
}
