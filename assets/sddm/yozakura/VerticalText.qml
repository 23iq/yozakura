pragma ComponentBehavior: Bound
import QtQuick
import "ClockText.js" as ClockText

// Upright vertical CJK text, one cell per character
// (modules/desktop/clockstyles/VerticalText.qml).
Column {
    id: column

    property string text: ""
    property color color: "white"
    property string family: ""
    property int weight: Font.Normal
    property real size: 16
    // Letter spacing in em.
    property real tracking: 0
    property real lineWidth: 1.45
    property real emAscent: 0.88

    width: lineWidth * size

    Repeater {
        model: ClockText.chars(column.text)

        Item {
            required property string modelData
            width: column.width
            height: column.size * (1 + column.tracking)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(column.emAscent * column.size - baselineOffset)
                text: parent.modelData
                color: column.color
                font.family: column.family
                font.weight: column.weight
                font.pixelSize: Math.max(1, Math.round(column.size))
                renderType: Text.QtRendering
            }
        }
    }
}
