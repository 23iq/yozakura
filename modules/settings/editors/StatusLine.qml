import "../Ui.js" as Ui
import QtQuick
import qs.config
import qs.modules.theme

// Status card used by editors: a tinted icon, a title and a detail line.
// `tone`: "ok" (primary), "warn" (tertiary), "error", "muted".
Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string detail: ""
    property string tone: "muted"
    default property alias actions: actionRow.data
    readonly property color accent: tone === "ok" ? Colors.primary : (tone === "warn" ? Colors.tertiary : (tone === "error" ? Colors.error : Colors.overSurfaceVariant))

    implicitHeight: Math.max(56, textColumn.implicitHeight + 24)

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(2), 18)
        color: Ui.alpha(root.accent, 0.08)
        border.width: 1
        border.color: Ui.alpha(root.accent, 0.3)
    }

    Rectangle {
        id: badge

        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 12
        color: Ui.alpha(root.accent, 0.16)

        Text {
            anchors.centerIn: parent
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 17
            color: root.accent
        }
    }

    Column {
        id: textColumn

        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: actionRow.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            visible: text !== ""
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
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
    }

    Row {
        id: actionRow

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
