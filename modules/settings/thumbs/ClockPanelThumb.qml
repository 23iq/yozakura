pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// Card picture of the clock popup's layout (bar.moduleOptions.clock.
// panelStyle): the popup under a piece of the bar, as a narrow column, a
// wide two-pane card or a grid of tiles, on the theme's popup surface.
MiniScreen {
    id: root

    property var entry
    property var value: "column"
    readonly property bool wide: value === "wide"
    readonly property bool bento: value === "bento"
    // [x, y, w, h] of the blocks inside the popup, as fractions of it.
    readonly property var blocks: bento ? [[0, 0, 0.62, 0.48], [0.66, 0, 0.34, 0.48], [0, 0.52, 0.34, 0.48], [0.38, 0.52, 0.62, 0.48]] : (wide ? [[0, 0, 0.46, 1], [0.52, 0, 0.48, 0.3], [0.52, 0.36, 0.48, 0.64]] : [[0, 0, 1, 0.34], [0, 0.4, 1, 0.24], [0, 0.7, 1, 0.3]])

    // the bar and its clock
    StyledRect {
        id: bar
        width: parent.width
        height: Math.round(root.u * 9)
        variant: "barbg"
        backgroundOpacity: root.barOpacity
        enableShadow: false
        radius: 0
        Mark {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width - width - root.u * 6
            width: root.u * 14
            height: Math.round(parent.height * 0.4)
            color: Colors.primary
        }
    }

    StyledRect {
        id: popup
        variant: "popup"
        enableShadow: false
        width: root.wide || root.bento ? root.u * 72 : root.u * 36
        height: root.height - bar.height - root.u * 8
        x: root.width - width - root.u * 4
        y: bar.height + root.u * 3
        radius: Look.radius("small", height)

        Item {
            anchors.fill: parent
            anchors.margins: Math.round(root.u * 3)
            Repeater {
                model: root.blocks
                delegate: Mark {
                    required property var modelData
                    required property int index
                    x: modelData[0] * parent.width
                    y: modelData[1] * parent.height
                    width: modelData[2] * parent.width
                    height: modelData[3] * parent.height
                    radius: Space.smallRadius / 2
                    color: index === 0 ? Qt.alpha(Colors.primary, 0.5) : Qt.alpha(Colors.overBackground, 0.14)
                }
            }
        }
    }
}
