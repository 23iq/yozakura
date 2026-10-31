pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.settings.previews
import "../Ui.js" as Ui

// Card picture of a screen edge (dock.position): a mini screen with a
// window and a short dock of app dots on the edge `value`.
ScreenBackdrop {
    id: root

    property var entry
    property var value: "bottom"
    readonly property bool vertical: value === "left" || value === "right"
    readonly property real thick: Math.max(8, Math.round(Math.min(width, height) * 0.16))
    readonly property real gap: Math.round(thick * 0.45)

    // a window in the middle
    Rectangle {
        x: root.width * 0.2
        y: root.height * 0.16
        width: root.width * 0.6
        height: root.height * 0.52
        radius: Math.min(Styling.radius(-4), 6)
        color: Ui.alpha(Colors.surface, 0.85)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Rectangle {
        id: dock
        readonly property real length: (root.vertical ? root.height : root.width) * 0.46
        width: root.vertical ? root.thick : length
        height: root.vertical ? length : root.thick
        x: root.value === "left" ? root.gap : (root.value === "right" ? root.width - width - root.gap : (root.width - width) / 2)
        y: root.value === "top" ? root.gap : (root.value === "bottom" ? root.height - height - root.gap : (root.height - height) / 2)
        radius: Math.min(width, height) / 2
        color: Ui.alpha(Colors.surfaceContainerHigh, 0.95)

        Grid {
            anchors.centerIn: parent
            rows: root.vertical ? 4 : 1
            columns: root.vertical ? 1 : 4
            spacing: Math.round(root.thick * 0.3)

            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: Math.round(root.thick * 0.5)
                    height: width
                    radius: width / 2
                    color: index === 0 ? Colors.primary : Ui.alpha(Colors.overSurface, 0.45)
                }
            }
        }
    }
}
