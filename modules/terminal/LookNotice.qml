import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// Inline status row of the terminal look (approximate preview, fish shell,
// another prompt in config.fish): tinted icon, title, message and its
// actions (children), which wrap under the text on narrow widths.
// `tone`: "info", "warning" or "ok".
StyledRect {
    id: root

    property string tone: "info"
    property string icon: "info"
    property string title: ""
    property string message: ""
    default property alias actions: actionRow.data

    readonly property color accent: root.tone === "warning" ? Colors.tertiary : (root.tone === "ok" ? Colors.green : Colors.primary)
    readonly property bool stacked: root.width < 560 && actionRow.implicitWidth > 0
    readonly property int pad: Space.m

    variant: "pane"
    enableShadow: false
    radius: Look.radius("box")
    implicitHeight: (root.stacked ? textCol.implicitHeight + actionRow.implicitHeight + Space.s : Math.max(textCol.implicitHeight, actionRow.implicitHeight, badge.height)) + root.pad * 2

    // the tone's tint over the pane
    Mark {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(root.accent, 0.08)
        border.width: Space.hairline
        border.color: Qt.alpha(root.accent, 0.3)
    }

    Mark {
        id: badge
        x: root.pad
        y: root.pad + (root.stacked ? 0 : Math.max(0, (root.height - root.pad * 2 - height) / 2))
        width: Space.controlXS
        height: width
        color: Qt.alpha(root.accent, 0.16)

        Icon {
            anchors.centerIn: parent
            icon: Icons[root.icon] ?? ""
            color: root.accent
        }
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: Space.m
        anchors.right: root.stacked ? parent.right : actionRow.left
        anchors.rightMargin: Space.m
        y: root.pad + (root.stacked ? 0 : Math.max(0, (root.height - root.pad * 2 - implicitHeight) / 2))
        spacing: Space.xs / 2

        KitText {
            width: parent.width
            text: root.title
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        KitText {
            width: parent.width
            visible: text !== ""
            role: "secondary"
            text: root.message
            wrapMode: Text.WordWrap
        }
    }

    Row {
        id: actionRow
        x: root.stacked ? textCol.x : root.width - width - root.pad
        y: root.stacked ? textCol.y + textCol.implicitHeight + Space.s : (root.height - height) / 2
        spacing: Space.s
    }
}
