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
                    required property int index
                    width: root.vertical ? parent.width : (bar.width - root.thick * 0.6) / 3
                    height: root.vertical ? (bar.height - root.thick * 0.6) / 3 : parent.height
                    Mark {
                        readonly property real len: root.thick * (index === 2 ? 1.6 : 0.9)
                        width: root.vertical ? root.thick * 0.4 : len
                        height: root.vertical ? len : root.thick * 0.4
                        x: root.vertical ? (parent.width - width) / 2 : (index === 0 ? 0 : (index === 2 ? parent.width - width : (parent.width - width) / 2))
                        y: root.vertical ? (index === 0 ? 0 : (index === 2 ? parent.height - height : (parent.height - height) / 2)) : (parent.height - height) / 2
                        color: index === 0 ? Colors.primary : Qt.alpha(Colors.overBackground, 0.7)
                    }
                }
            }
        }
    }
}
