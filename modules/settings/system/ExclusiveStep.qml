import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// One line of the exclusive-mode card: a tinted icon, a title and a detail.
Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string detail: ""
    property bool mono: false
    property color accent: Colors.primary

    implicitHeight: Math.max(36, textCol.implicitHeight)

    Rectangle {
        id: badge
        width: 36
        height: 36
        radius: Math.min(Styling.radius(2), 14)
        color: Ui.alpha(root.accent, 0.14)
        Text {
            anchors.centerIn: parent
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(2)
            color: root.accent
        }
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: root.title
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.detail
            wrapMode: Text.WrapAnywhere
            font.family: root.mono ? "monospace" : Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
    }
}
