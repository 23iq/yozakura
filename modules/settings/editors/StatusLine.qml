import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Status card used by editors: an icon in the tone's color, a title (body)
// and a detail line (caption) in the language's control box, actions on the
// right. `tone`: "ok" (accent: the active state), "warn" (tertiary),
// "error", "muted".
Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string detail: ""
    property string tone: "muted"
    default property alias actions: actionRow.data
    readonly property color accent: tone === "ok" ? Type.accent : (tone === "warn" ? Colors.tertiary : (tone === "error" ? Colors.error : Type.secondary))
    readonly property int inset: Look.controlFill(false).a > 0 || Look.controlEdge.a > 0 ? Space.m : 0

    implicitHeight: Math.max(Space.rowHeight, textColumn.implicitHeight + Space.m * 2)

    ControlBox {
        radius: Look.chipRadius(Space.chip)
    }

    Text {
        id: badge

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: Type.iconSize("title")
        horizontalAlignment: Text.AlignHCenter
        text: Icons[root.icon] ?? ""
        font.family: Icons.font
        font.pixelSize: Type.iconSize("title")
        color: root.accent
    }

    Column {
        id: textColumn

        anchors.left: badge.right
        anchors.leftMargin: Space.m
        anchors.right: actionRow.left
        anchors.rightMargin: Space.m
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs / 2

        KitText {
            width: parent.width
            visible: text !== ""
            role: "body"
            text: root.title
            wrapMode: Text.WordWrap
        }

        KitText {
            width: parent.width
            visible: text !== ""
            role: "caption"
            text: root.detail
            wrapMode: Text.WordWrap
        }
    }

    Row {
        id: actionRow

        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs
    }
}
