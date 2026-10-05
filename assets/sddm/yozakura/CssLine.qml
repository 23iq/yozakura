import QtQuick

// One line of text in a box of a given line height, glyphs placed like CSS
// (modules/desktop/clockstyles/CssLine.qml).
Item {
    id: line

    property alias text: label.text
    property alias color: label.color
    property string family: ""
    property int weight: Font.Normal
    property real size: 16
    // Letter spacing in em.
    property real tracking: 0
    property real lineHeight: size

    implicitWidth: label.implicitWidth
    implicitHeight: lineHeight
    width: implicitWidth
    height: implicitHeight

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
    }
}
