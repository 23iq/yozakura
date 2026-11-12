import QtQuick
import qs.modules.components

// Who draws a screen's frame (performance.splitFrame, phase 1 of
// docs/perf-panel-split.md): its own layer window (FrameWindow, Top layer)
// or, as before, the unified panel.
//
// The window draws it while the flag and the frame are on and no
// fullscreen window covers the screen. Under a fullscreen window the frame
// goes back into the panel (an Overlay surface: the frame's restoration
// around a revealed bar shows above the fullscreen client, a Top surface
// would not) and the window unmaps once the fullscreen state has held for
// `settleInterval` ms (a quick fullscreen toggle remaps nothing). Handover
// order: leaving the panel, the window maps first and the panel stops
// drawing `handoverMs` later (the window's first frame is up by then);
// back to the panel, the panel draws at once.
QtObject {
    id: root

    property bool enabled: false
    property bool frameEnabled: false
    property bool fullscreen: false
    property int settleInterval: 250
    property int handoverMs: 50

    // The flag and the frame are on: the window exists (FrameWindow loader)
    readonly property bool windowWanted: root.enabled && root.frameEnabled
    // The window should draw the frame now
    readonly property bool wanted: root.windowWanted && !root.fullscreen
    // The window is mapped: at once when wanted, and otherwise until the
    // unwanted state has settled (a fullscreen flip), never without the flag
    readonly property bool windowShown: root.windowWanted && (root.wanted || root._held.output === true || !root._held.settled)
    // The panel draws the frame (and its shadow): always without the flag
    readonly property bool panelDraws: !(root.wanted && root.windowShown && root._arrived)

    property bool _arrived: false
    onWindowShownChanged: {
        if (root.windowShown) {
            root._handover.restart();
        } else {
            root._handover.stop();
            root._arrived = false;
        }
    }

    property SettleGate _held: SettleGate {
        value: root.wanted
        interval: root.settleInterval
    }
    property Timer _handover: Timer {
        interval: root.handoverMs
        onTriggered: root._arrived = true
    }

    Component.onCompleted: {
        if (root.windowShown)
            root._handover.restart();
    }
}
