pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.components.kit
import "../components/preview/Preview.js" as Preview

// The dock's row (or column, `vertical`) of items: the pin toggle, the app
// buttons (TaskbarApps) and the overview button, the two buttons set off
// by dividers (dock.showPinButton / dock.showOverviewButton).
GridLayout {
    id: root

    required property ShellScreen screen
    property bool vertical: false
    // The edge the app buttons face (their running indicators).
    property string position: "bottom"
    property bool pinned: false
    // A settings preview (DockContent.preview): its looks, null live
    property var preview: null
    readonly property real iconSize: Preview.pick(root.preview, "dock.iconSize", Config.dock?.iconSize ?? 40)
    readonly property real dividerLength: root.iconSize * 0.6

    signal pinToggled

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rows: root.vertical ? -1 : 1
    columns: root.vertical ? 1 : -1
    rowSpacing: Config.dock?.spacing ?? 4
    columnSpacing: Config.dock?.spacing ?? 4

    component Separator: Loader {
        visible: active
        Layout.alignment: Qt.AlignCenter
        sourceComponent: Divider {
            vertical: !root.vertical
            implicitWidth: root.vertical ? root.dividerLength : Space.hairline
            implicitHeight: root.vertical ? Space.hairline : root.dividerLength
        }
    }

    Loader {
        active: Config.dock?.showPinButton ?? true
        visible: active
        Layout.alignment: Qt.AlignCenter
        sourceComponent: DockPinButton {
            pinned: root.pinned
            onToggled: root.pinToggled()
        }
    }

    Separator {
        active: Config.dock?.showPinButton ?? true
    }

    Repeater {
        model: TaskbarApps.apps

        DockAppButton {
            required property var modelData
            appToplevel: modelData
            Layout.alignment: Qt.AlignCenter
            dockPosition: root.position
            preview: root.preview
            iconSize: root.iconSize
        }
    }

    Separator {
        active: Config.dock?.showOverviewButton ?? true
    }

    Loader {
        active: Config.dock?.showOverviewButton ?? true
        visible: active
        Layout.alignment: Qt.AlignCenter
        sourceComponent: DockOverviewButton {
            screen: root.screen
        }
    }
}
