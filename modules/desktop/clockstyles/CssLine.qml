import QtQuick

// One line of text in a box of a given line height, with the glyphs placed
// like CSS does (half-leading around ascent + descent), so designs specified
// with `line-height` port over exactly.
Item {
    id: line

    property alias text: label.text
    property alias color: label.color
    property string family: ""
    property int weight: Font.Normal
    property real size: 16
    // Letter spacing in em.
    property real tracking: 0
    // Line box height in px (CSS line-height).
    property real lineHeight: size
    property int colorDuration: 0

    implicitWidth: label.implicitWidth
    implicitHeight: lineHeight

    FontMetrics {
        id: metrics
        font: label.font
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((line.lineHeight - metrics.ascent - metrics.descent) / 2 + metrics.ascent - baselineOffset)
        font.family: line.family
        font.weight: line.weight
        font.pixelSize: Math.max(1, Math.round(line.size))
        font.letterSpacing: line.tracking * line.size
        renderType: Text.QtRendering
        antialiasing: true

        Behavior on color {
            enabled: line.colorDuration > 0
            ColorAnimation {
                duration: line.colorDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
