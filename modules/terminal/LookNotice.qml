import QtQuick
import qs.config
import qs.modules.theme
import "../settings/Ui.js" as Ui

// Inline status row of the terminal look (approximate preview, fish shell,
// another prompt in config.fish): tinted icon, title, message and its
// actions (children), which wrap under the text on narrow widths.
// `tone`: "info", "warning" or "ok".
Item {
    id: root

    property string tone: "info"
    property string icon: "info"
    property string title: ""
    property string message: ""
    default property alias actions: actionRow.data

    readonly property color accent: root.tone === "warning" ? Colors.tertiary : (root.tone === "ok" ? Colors.green : Colors.primary)
    readonly property bool stacked: root.width < 560 && actionRow.implicitWidth > 0

    implicitHeight: (root.stacked ? textCol.implicitHeight + actionRow.implicitHeight + 10 : Math.max(textCol.implicitHeight, actionRow.implicitHeight, 30)) + 20

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(1), 14)
        color: Ui.alpha(root.accent, 0.08)
        border.width: 1
        border.color: Ui.alpha(root.accent, 0.3)
    }

    Rectangle {
        id: badge
        x: 12
        y: 10 + (root.stacked ? 0 : Math.max(0, (root.height - 20 - height) / 2))
        width: 30
        height: 30
        radius: 15
        color: Ui.alpha(root.accent, 0.16)
        Text {
            anchors.centerIn: parent
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: root.accent
        }
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: root.stacked ? parent.right : actionRow.left
        anchors.rightMargin: 14
        y: 10 + (root.stacked ? 0 : Math.max(0, (root.height - 20 - implicitHeight) / 2))
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
            color: Colors.overBackground
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.message
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }

    Row {
        id: actionRow
        x: root.stacked ? textCol.x : root.width - width - 12
        y: root.stacked ? textCol.y + textCol.implicitHeight + 10 : (root.height - height) / 2
        spacing: 8
    }
}
