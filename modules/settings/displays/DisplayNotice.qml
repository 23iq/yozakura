import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// Inline banner of the Displays page: tinted icon, title, message and
// (as children) its action buttons. `tone`: "info", "warning" or "error".
StyledRect {
    id: root

    property string tone: "info"
    property string icon: "info"
    property string title: ""
    property string message: ""
    default property alias actions: actionRow.data

    readonly property color accent: tone === "error" ? Colors.error : (tone === "warning" ? Colors.tertiary : Colors.primary)

    variant: "pane"
    radius: Look.radius("box")
    enableShadow: false
    implicitHeight: Math.max(textCol.implicitHeight, actionRow.implicitHeight) + 32

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Ui.alpha(root.accent, 0.1)
        border.width: 1
        border.color: Ui.alpha(root.accent, 0.45)
        z: 10
    }

    Rectangle {
        id: badge
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: width / 2
        color: Ui.alpha(root.accent, 0.2)
        Icon {
            role: "title"
            anchors.centerIn: parent
            icon: Icons[root.icon] ?? ""
            color: root.accent
        }
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: Space.l
        anchors.right: actionRow.left
        anchors.rightMargin: Space.l
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs

        KitText {
            width: parent.width
            text: root.title
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        KitText {
            role: "secondary"
            width: parent.width
            visible: text !== ""
            text: root.message
            wrapMode: Text.WordWrap
        }
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: Space.l
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.s
    }
}
