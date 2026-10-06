import QtQuick
import Quickshell

// Per-screen display overlays (a Variants delegate of shell.qml): the
// keep/revert prompt of a pending live layout change and the identify
// numbers. Both windows stay unmapped until they have something to show.
Scope {
    id: root

    required property ShellScreen modelData

    DisplayConfirmOverlay {
        targetScreen: root.modelData
    }

    DisplayIdentifyOverlay {
        targetScreen: root.modelData
    }
}
