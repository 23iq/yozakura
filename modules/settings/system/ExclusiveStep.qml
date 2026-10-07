import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One step of exclusive mode (settings card, onboarding): a muted glyph in
// the language's control box, a body title and a wrapping secondary detail
// (`mono` for unit / path lists). Decoration only: the accent is not used.
Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string detail: ""
    property bool mono: false
    // A visible control box (glass, tiles); in ink the bare glyph lines up
    // with the StatusLine icon above it.
    readonly property bool boxed: Look.controlFill(false).a > 0 || Look.controlEdge.a > 0

    implicitHeight: Math.max(badge.height, textCol.implicitHeight)

    Item {
        id: badge
        width: root.boxed ? Space.controlS : Type.iconSize("title")
        height: Space.controlS

        ControlBox {
            radius: Look.buttonRadius(parent.height)
        }

        Text {
            anchors.centerIn: parent
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: Type.secondary
        }
    }

    Column {
        id: textCol
        anchors.left: badge.right
        anchors.leftMargin: Space.m
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs / 2

        KitText {
            width: parent.width
            role: "body"
            text: root.title
            wrapMode: Text.WordWrap
            font.weight: Look.labelWeight
        }
        KitText {
            width: parent.width
            visible: text !== ""
            role: "secondary"
            text: root.detail
            wrapMode: Text.WrapAnywhere
            font.family: root.mono ? "monospace" : Type.bodyFont
        }
    }
}
