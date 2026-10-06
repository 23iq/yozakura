pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services

// The bar's tray where it lives while the bar is off: a row (or column) of
// tray icons in a notch segment or a corner pill. Left click activates,
// right click opens the item's menu; icons the user hid in the bar's tray
// overflow stay hidden.
Grid {
    id: root

    property real iconSize: Metrics.iconSize
    property bool vertical: false
    readonly property var items: (SystemTray.items?.values ?? []).filter(i => !StateService.systrayHidden.includes(i.id))

    objectName: "rehomedTray"
    rows: root.vertical ? -1 : 1
    columns: root.vertical ? 1 : -1
    spacing: Math.round(Metrics.spacing * 0.75)
    visible: root.items.length > 0

    Repeater {
        model: root.items

        MouseArea {
            id: cell
            required property SystemTrayItem modelData
            width: root.iconSize
            height: root.iconSize
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.RightButton && cell.modelData.hasMenu)
                    menu.open();
                else
                    cell.modelData.activate();
            }

            IconImage {
                anchors.fill: parent
                source: cell.modelData.icon
                smooth: true
            }

            QsMenuAnchor {
                id: menu
                menu: cell.modelData.menu
                anchor.item: cell
            }
        }
    }
}
