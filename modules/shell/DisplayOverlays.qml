import QtQuick
import Quickshell
import qs.modules.services

// Per-screen display overlays (a Variants delegate of shell.qml), each
// loaded only while it has something to show: the keep/revert prompt of a
// pending live layout change and the identify numbers.
Scope {
    id: root

    required property ShellScreen modelData

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

    Loader {
        active: DisplaysService.pending && DisplaysService.session.live
        source: "DisplayConfirmOverlay.qml"
        onItemChanged: if (item)
            item.targetScreen = root.modelData
    }

    Loader {
        active: DisplaysService.identified.length > 0 || lingering.running
        source: "DisplayIdentifyOverlay.qml"
        onItemChanged: if (item)
            item.targetScreen = root.modelData
    }
}
