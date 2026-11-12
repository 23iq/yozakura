import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// Card picture of the bar's edge (bar.position): a screen with the bar on
// edge `value`, drawn on the theme's bar surface, and a window beside it.
MiniScreen {
    id: root

    property var entry
    property var value: "top"
    readonly property bool vertical: value === "left" || value === "right"
    readonly property real thick: Math.max(Space.s, Math.round(root.u * 7))

    // a window in the room the bar leaves
    Mark {
        x: (root.value === "left" ? root.thick : 0) + root.u * 12
        y: (root.value === "top" ? root.thick : 0) + root.u * 9
        width: root.width - root.thick * (root.vertical ? 1 : 0) - root.u * 24
        height: root.height - root.thick * (root.vertical ? 0 : 1) - root.u * 18
        radius: Space.smallRadius
        color: Qt.alpha(Colors.surfaceContainer, 0.85)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)
    }

    StyledRect {
        id: bar
        variant: "barbg"
        backgroundOpacity: root.barOpacity
        enableShadow: false
        radius: 0
        width: root.vertical ? root.thick : root.width
        height: root.vertical ? root.height : root.thick
        x: root.value === "right" ? root.width - width : 0
        y: root.value === "bottom" ? root.height - height : 0

        // launcher, a few modules and the clock
        Grid {
            anchors.fill: parent
            anchors.margins: Math.round(root.thick * 0.3)
            rows: root.vertical ? 3 : 1
            columns: root.vertical ? 1 : 3
            Repeater {
                model: 3
                delegate: Item {
                    id: cell
                    required property int index
                    width: root.vertical ? bar.width - root.thick * 0.6 : (bar.width - root.thick * 0.6) / 3
                    height: root.vertical ? (bar.height - root.thick * 0.6) / 3 : bar.height - root.thick * 0.6
                    Mark {
                        readonly property real len: root.thick * (cell.index === 2 ? 1.6 : 0.9)
                        width: root.vertical ? root.thick * 0.4 : len
                        height: root.vertical ? len : root.thick * 0.4
                        x: root.vertical ? (cell.width - width) / 2 : (cell.index === 0 ? 0 : (cell.index === 2 ? cell.width - width : (cell.width - width) / 2))
                        y: root.vertical ? (cell.index === 0 ? 0 : (cell.index === 2 ? cell.height - height : (cell.height - height) / 2)) : (cell.height - height) / 2
                        color: cell.index === 0 ? Colors.primary : Qt.alpha(Colors.overBackground, 0.7)
                    }
                }
            }
        }
    }
}
