pragma Singleton
import QtQuick
import Quickshell
import qs.modules.bar.workspaces
import qs.modules.services

// "Close the overview and activate this window": the one path behind a click
// on a preview and Enter on a search match, in every overview style.
//
// The overview is an Overlay layer with exclusive keyboard focus, and it
// stays mapped for its close animation. Hyprland refuses keyboard focus to a
// window while such a layer is up: a focuswindow sent then switches the
// workspace, leaves the window unfocused, and focus goes back to the previous
// window when the layer lets go. So the request is sent twice:
//   1. at once: the workspace switch starts with the click (niri and MangoWC
//      remember the target under the layer, there this is all it takes),
//   2. again when the last overview surface has unmapped (OverviewPopup
//      reports through setMapped): the one Hyprland grants. Focusing the
//      focused window changes nothing on any compositor.
// The second request leaves on the next turn of the event loop: the report
// comes from the latch, in the tick that hides the window, and the unmap
// has to be on its way to the compositor first.
Singleton {
    id: root

    // The overview layer surfaces (one per screen) that are mapped. A
    // surface reports its unmap and its destruction itself.
    property var _surfaces: []
    readonly property bool mapped: root._surfaces.length > 0
    // Address of the window waiting for the unmap; "" when none is.
    property string pending: ""

    function setMapped(surface, mapped) {
        const rest = root._surfaces.filter(s => s !== surface);
        if (mapped)
            rest.push(surface);
        root._surfaces = rest;
        if (!root.mapped && root.pending !== "")
            Qt.callLater(root._confirm);
    }

    function activate(address) {
        if (address === undefined || address === null || address === "")
            return;
        const target = String(address);
        Visibilities.setActiveModule("");
        root._focus(target);
        // Nothing waits when the overview stayed open (no focused monitor)
        // or has no surface left: the request above was the last word.
        root.pending = Visibilities.currentActiveModule === "" && root.mapped ? target : "";
    }

    function _focus(address) {
        YozdService.dispatch(`focuswindow address:${address}`);
    }

    // A window closed while the overview was closing is not asked for again.
    function _confirm() {
        if (root.mapped)
            return;
        const target = root.pending;
        root.pending = "";
        if (target !== "" && CompositorData.windowByAddress[target] !== undefined)
            root._focus(target);
    }

    // The overview (or another module) opened again before the unmap: the
    // user moved on, a focus arriving later would only steal it.
    Connections {
        target: Visibilities
        function onCurrentActiveModuleChanged() {
            if (Visibilities.currentActiveModule !== "")
                root.pending = "";
        }
    }
}
