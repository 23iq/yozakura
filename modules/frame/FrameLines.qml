import QtQuick
import qs.modules.theme
import qs.config

// Double hairline drawn on the screen frame (shoji / passe-partout look):
// one line hugging the window area, one running along the screen edge.
// On only when the frame has its own surface (theme.srFrame.inheritBg
// false) with a border: theme.srFrame.border = [colour spec, width px].
// Panels are drawn above the frame, so the lines pass under their tabs.
Item {
    id: root

    objectName: "frameLines"

    property real holeX: 0
    property real holeY: 0
    property real holeWidth: 0
    property real holeHeight: 0
    property real innerRadius: 0
    // Thinnest frame edge: the outer line sits in its middle
    property real thickness: 0

    readonly property var frameSpec: Config.theme.srFrame
    readonly property var border: frameSpec && !frameSpec.inheritBg ? frameSpec.border : null
    readonly property real lineWidth: border && border.length > 1 ? border[1] : 0
    readonly property color lineColor: border ? Config.resolveColor(border[0]) : "transparent"
    // Room for two lines with a visible gap between them
    readonly property bool shown: lineWidth > 0 && thickness >= 3 * lineWidth + 2 && holeWidth > 0 && holeHeight > 0
    readonly property real outerInset: Math.max(1, Math.floor((thickness - lineWidth) / 2) - lineWidth)
    readonly property real screenRadius: Config.theme.enableCorners ? Styling.radius(4) + thickness : 0

    visible: shown

    Rectangle {
        x: root.holeX - root.lineWidth
        y: root.holeY - root.lineWidth
        width: root.holeWidth + 2 * root.lineWidth
        height: root.holeHeight + 2 * root.lineWidth
        radius: root.innerRadius > 0 ? root.innerRadius + root.lineWidth : 0
        color: "transparent"
        border.color: root.lineColor
        border.width: root.lineWidth
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.outerInset
        radius: Math.max(0, root.screenRadius - root.outerInset)
        color: "transparent"
        border.color: root.lineColor
        border.width: root.lineWidth
        antialiasing: true
    }
}
