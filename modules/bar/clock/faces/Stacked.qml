pragma ComponentBehavior: Bound
import QtQuick

// Hours over minutes (the vertical bar face; also selectable on a
// horizontal bar, where two short lines fit into the bar height).
Column {
    id: root

    required property var clock

    objectName: "faceStacked"
    spacing: 0

    Repeater {
        model: root.clock.parts.suffix !== "" ? [root.clock.parts.hours, root.clock.parts.minutes, root.clock.parts.suffix] : [root.clock.parts.hours, root.clock.parts.minutes]

        Text {
            required property string modelData
            required property int index
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            horizontalAlignment: Text.AlignHCenter
            text: modelData
            color: root.clock.textColor
            font.family: root.clock.fontFamily
            font.pixelSize: Math.round(root.clock.fontSize * (index === 2 ? 0.6 : (root.clock.vertical ? 1 : 0.8)))
            font.bold: true
            font.features: {
                "tnum": 1
            }
            lineHeight: root.clock.vertical ? 1 : 0.85
        }
    }
}
