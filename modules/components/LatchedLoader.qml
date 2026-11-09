import QtQuick

// A Loader for a layer window that closes through SurfaceLatch: the window
// is created when `wanted`, and after `wanted` goes false it stays loaded
// until it has unmapped itself (its latch drops keyboard focus first and
// unmaps at least a frame later), so it is never destroyed in the tick its
// keyboard focus goes away (a QtWayland crash with a text field holding
// input-method focus).
//
// The loaded window exposes `mapped` (bind it to its latch's `shown`).
// `allowed` false (e.g. suspend) unloads at once.
Loader {
    id: root

    property bool wanted: false
    property bool allowed: true

    // Opened and not yet unmapped since: kept loaded.
    property bool _held: false

    active: root.allowed && (root.wanted || root._held)

    onWantedChanged: {
        if (root.wanted)
            root._held = true;
    }
    // Unloaded at once (suspend): nothing is held over to the resume.
    onAllowedChanged: root._held = root.allowed && root.wanted

    // Not a binding on `item`: `active` would then depend on the item it
    // creates (a binding loop). The unmap arrives from the latch's timer.
    readonly property var _window: root.item
    Connections {
        target: root.item
        ignoreUnknownSignals: true
        function onMappedChanged() {
            root._held = !!root._window && root._window.mapped === true;
        }
    }
}
