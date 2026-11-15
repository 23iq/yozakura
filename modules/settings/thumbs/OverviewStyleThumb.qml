pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of an overview style (overview.style): the dimmed screen
// with the workspaces as a grid of two rows, one strip, or a tape of
// larger previews running off the right edge.
MiniScreen {
    id: root

    property var entry
    property var value: "grid"
    readonly property int rows: root.value === "grid" ? 2 : 1
    readonly property int cols: root.value === "scroll" ? 4 : 4
    readonly property real gap: root.u * 2
    readonly property real tileW: root.value === "scroll" ? root.width * 0.36 : root.width * 0.18
    readonly property real tileH: root.tileW * 0.56

    Mark {
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colors.shadow, 0.5)
    }
    Grid {
        x: root.value === "scroll" ? root.u * 6 : (root.width - (root.tileW * root.cols + root.gap * (root.cols - 1))) / 2
        y: (root.height * 0.82 - (root.tileH * root.rows + root.gap * (root.rows - 1))) / 2
        columns: root.cols
        spacing: root.gap
        Repeater {
            model: root.rows * root.cols
            delegate: Mark {
                required property int index
                width: root.tileW
                height: root.tileH
                radius: root.u * 1.5
                color: index === 0 ? Qt.alpha(Type.accent, 0.3) : Qt.alpha(Colors.surfaceContainerHigh, 0.85)
                border.width: index === 0 ? Space.stroke - 1 : Space.hairline
                border.color: index === 0 ? Type.accent : Type.hairline
            }
        }
    }
}
