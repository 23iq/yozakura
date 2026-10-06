import QtQuick
import Quickshell
import qs.modules.services

// Per-screen display overlays, each alive only while it has something to
// show: the keep/revert prompt of a pending live layout change and the
// identify numbers.
Scope {
    id: root

    required property ShellScreen targetScreen

    Loader {
        active: DisplaysService.pending && DisplaysService.session.live
        sourceComponent: DisplayConfirmOverlay {
            targetScreen: root.targetScreen
        }
    }

    // Stays alive a moment after the numbers clear so they can fade out
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
        active: DisplaysService.identified.length > 0 || lingering.running
        sourceComponent: DisplayIdentifyOverlay {
            targetScreen: root.targetScreen
        }
    }
}
