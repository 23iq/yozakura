pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.shell.hosts

// Per-screen holder of the menu overlay: nothing is created while both
// menus use the notch style (the default).
Item {
    id: root

    required property ShellScreen screen

    Loader {
        active: HostRouter.powermenuStyle !== "notch" || HostRouter.toolsStyle !== "notch"
        sourceComponent: MenuOverlay {
            screen: root.screen
        }
    }
}
