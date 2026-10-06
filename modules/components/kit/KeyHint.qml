import QtQuick
import qs.modules.theme

// A small outlined keycap for shortcut hints: `KeyHint { text: "Esc" }` or
// `KeyHint { icon: Icons.arrowUp }`.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""

    implicitHeight: Space.keyHint
    implicitWidth: Math.max(height, (root.icon !== "" ? glyph.implicitWidth : label.implicitWidth) + Space.s * 2 - 2)
    radius: Space.clampRadius(Space.smallRadius, height)
    color: "transparent"
    border.width: Space.hairline
    border.color: Qt.rgba(Type.muted.r, Type.muted.g, Type.muted.b, 0.5)

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text !== "" ? root.text : root.icon

    KitText {
        id: label
        anchors.centerIn: parent
        visible: root.icon === ""
        role: "caption"
        color: Type.secondary
        font.weight: Font.Medium
        text: root.text
    }

    Text {
        id: glyph
        anchors.centerIn: parent
        visible: root.icon !== ""
        text: root.icon
        font.family: Icons.font
        font.pixelSize: Type.size("caption")
        color: Type.secondary
    }
}
