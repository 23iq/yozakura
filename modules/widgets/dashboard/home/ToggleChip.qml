import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// A quick toggle of the composed dashboard: icon + label on a StyledRect,
// with ControlButton's variants (primary when on, focus on hover, common
// otherwise), so the visual language decides how loud it is (ink: a ghost,
// and a soft accent tint when on).
StyledRect {
    id: root

    property string icon
    property string label
    property bool active: false
    readonly property bool hovered: area.containsMouse

    signal clicked
    signal rightClicked

    variant: root.active ? (root.hovered ? "primaryfocus" : "primary") : (root.hovered ? "focus" : "common")
    enableShadow: false
    radius: Styling.radius(0)
    implicitWidth: content.implicitWidth + Metrics.padding * 1.5
    implicitHeight: Metrics.iconSize + Metrics.spacing

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Metrics.spacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(2)
            color: root.active ? root.item : Colors.overBackground

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Metrics.menuW * 0.75)
            text: root.label
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: root.active ? Font.Medium : Font.Normal
            color: root.active ? root.item : Colors.overSurfaceVariant
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
