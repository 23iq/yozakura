import QtQuick
import Quickshell
import qs.modules.components
import qs.modules.services

// Per-screen display overlays (a Variants delegate of shell.qml), each
// loaded only while it has something to show: the keep/revert prompt of a
// pending live layout change and the identify numbers.
Scope {
    id: root

    required property ShellScreen modelData

    // Outputs churn while a live layout applies (modes, hotplug): overlay
    // windows are created only once the outputs (the list and each one's
    // geometry) have held still for a moment, and only while this
    // delegate's screen is still among them.
    SettleGate {
        id: outputs
        value: Quickshell.screens.map(s => s ? [s.name, s.x, s.y, s.width, s.height].join(":") : "").join(" ")
        interval: 400
        startSettled: false
    }
    readonly property bool screenReady: outputs.settled && Quickshell.screens.indexOf(root.modelData) >= 0

    // The prompt comes up when the apply call returns, which is when the
    // compositor starts changing outputs: it too waits out a settle period
    // (and goes away at once when the session ends).
    readonly property bool confirmWanted: DisplaysService.pending && DisplaysService.session.live
    SettleGate {
        id: confirmSettled
        value: root.confirmWanted
        interval: 400
    }

    // The identify window outlives the numbers a moment so they fade out
    Timer {
        id: lingering
        interval: 600
    }

    Connections {
        target: DisplaysService
        function onIdentifiedChanged() {
            if (DisplaysService.identified.length === 0)
                lingering.restart();
        }
    }

    // targetScreen is an initial property: the window is created on its
    // screen instead of being moved there after creation
    Loader {
        active: root.screenReady && root.confirmWanted && confirmSettled.settled && confirmSettled.output === true
        Component.onCompleted: setSource("DisplayConfirmOverlay.qml", {
            "targetScreen": root.modelData
        })
    }

    Loader {
        active: root.screenReady && (DisplaysService.identified.length > 0 || lingering.running)
        Component.onCompleted: setSource("DisplayIdentifyOverlay.qml", {
            "targetScreen": root.modelData
        })
    }
}
