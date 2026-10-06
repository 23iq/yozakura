pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.shell.hosts
import qs.config

// Per-screen fullscreen host of the keybind cheatsheet (shell.qml, one per
// screen, layout.cheatsheet.host "fullscreen"):
// the window exists while the "keybinds" module is open on this screen and
// for the closing animation after.
Item {
    id: root

    required property ShellScreen targetScreen

    readonly property var screenVisibilities: Visibilities.getForScreen(targetScreen.name)
    // Only the "fullscreen" host; spotlight/sheet are HostedSurfaces'
    readonly property bool open: HostRouter.moduleIn(screenVisibilities, "fullscreen") === "cheatsheet"
    property bool closing: false

    onOpenChanged: {
        if (!open) {
            closing = true;
            closingTimer.restart();
        }
    }

    Timer {
        id: closingTimer
        interval: Config.animDuration + 60
        onTriggered: root.closing = false
    }

    Loader {
        active: SuspendManager.wakeReady && (root.open || root.closing)
        sourceComponent: CheatsheetWindow {
            screen: root.targetScreen
            open: root.open
        }
    }
}
