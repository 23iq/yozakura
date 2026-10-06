import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.extras
import qs.config
import "../settings/Ui.js" as Ui

// One card of the setup summary: a tinted icon, a small label and the
// value; `percent` >= -1 with `busy` adds a live progress line under it
// (installs still running).
StyledRect {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property bool busy: false
    property int percent: -1
    property bool muted: false
    property color accent: Colors.primary

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(4)
    implicitHeight: Math.round(Styling.fontSize(0) * 5.2)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.5)
        z: 10
    }

    Rectangle {
        id: disc
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(Styling.fontSize(0) * 2.6)
        height: width
        radius: width / 2
        color: Ui.alpha(root.accent, root.muted ? 0.08 : 0.16)
        Text {
            anchors.centerIn: parent
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(2)
            color: root.muted ? Colors.outline : root.accent
        }
    }

    Column {
        anchors.left: disc.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4
            color: Colors.outline
        }
        Text {
            objectName: "value"
            width: parent.width
            text: root.value
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: root.muted ? Colors.overSurfaceVariant : Colors.overBackground
        }
        Item {
            visible: root.busy
            width: parent.width
            height: 8
            ProgressTrack {
                objectName: "progress"
                anchors.bottom: parent.bottom
                width: parent.width
                implicitHeight: 4
                percent: root.percent
            }
        }
    }
}
