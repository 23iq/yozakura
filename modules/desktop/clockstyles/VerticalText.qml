pragma ComponentBehavior: Bound
import QtQuick
import "ClockText.js" as ClockText
import qs.modules.theme

// Upright vertical CJK text (CSS writing-mode: vertical-rl for one line).
// Qt has no vertical text layout: one cell per character, stacked.
Column {
    id: column

    property string text: ""
    property color color: "white"
    property string family: ""
    property int weight: Font.Normal
    property real size: 16
    // Letter spacing in em, added after every character like CSS.
    property real tracking: 0
    // Column width in em (CSS line-height; "normal" for CJK fonts ≈ 1.45).
    property real lineWidth: 1.45
    // Ideographic em box top above the baseline, in em.
    property real emAscent: 0.88
    property int colorDuration: 0

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
                antialiasing: true

                Behavior on color {
                    enabled: column.colorDuration > 0
                    ColorAnimation {
                        duration: column.colorDuration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
    }
}
