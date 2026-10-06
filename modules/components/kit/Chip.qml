import QtQuick
import qs.modules.theme
import qs.modules.components
import "KitStates.js" as KitStates
import qs.modules.components.kit

// Icon + label toggle. Inactive: the language's "common" box (a ghost in
// ink); `active`: accent tint with accent icon and label.
StyledRect {
    id: root

    property string icon: ""
    property string text: ""
    property bool active: false
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property string look: KitStates.look(false, root.active, root.hovered && root.enabled)
    readonly property color ink: root.active ? Type.accent : Type.text

    signal clicked

    implicitHeight: Space.chip
    implicitWidth: row.implicitWidth + Space.m * 2
    variant: KitStates.variant(root.look, "common")
    backgroundOpacity: KitStates.opacity(root.look, root.hovered)
    enableBorder: !root.active
    radius: Space.clampRadius(Space.controlRadius, height)
    opacity: root.enabled ? 1 : 0.38

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.active

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Space.s

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Icons.font
            font.pixelSize: Type.iconSize("secondary")
            color: root.ink
        }

        KitText {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            text: root.text
            color: root.ink
            font.weight: root.active ? Font.Medium : Font.Normal
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
