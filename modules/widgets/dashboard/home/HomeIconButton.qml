import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Round icon button of the composed dashboard (player transport, Clear): a
// ghost that shows the focus variant on hover; `accent` makes it the primary
// variant (ink: a soft tint with an accent glyph).
StyledRect {
    id: root

    property string icon
    property bool accent: false
    property real iconSize: Styling.fontSize(2)
    readonly property bool hovered: area.containsMouse

    signal clicked

    variant: root.accent ? (root.hovered ? "primaryfocus" : "primary") : (root.hovered && root.enabled ? "focus" : "common")
    enableShadow: false
    radius: root.accent ? width / 2 : Styling.radius(0)
    implicitWidth: Metrics.iconSize + Metrics.spacing
    implicitHeight: implicitWidth
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Icons.font
        font.pixelSize: root.iconSize
        color: root.accent ? root.item : Colors.overBackground
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
