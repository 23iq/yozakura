import QtQuick
import qs.modules.theme
import qs.modules.components
import "KitStates.js" as KitStates

// Round icon button. Sizes "s" (36) / "m" (40). Normal is the language's
// "common" box (a ghost in ink), hover / `highlighted` the focus look,
// `active` an accent tint with an accent glyph, `primary` the one filled
// accent action of a surface.
StyledRect {
    id: root

    property string icon: ""
    property string size: "m"
    property bool active: false
    property bool primary: false
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property bool pressed: mouse.pressed
    readonly property string look: KitStates.look(root.primary, root.active, root.hovered && root.enabled)

    signal clicked

    implicitWidth: root.size === "s" ? Space.controlS : Space.controlM
    implicitHeight: implicitWidth
    variant: KitStates.variant(root.look, "common")
    backgroundOpacity: KitStates.opacity(root.look, root.hovered)
    enableBorder: root.look === "normal" || root.look === "hover"
    radius: Space.round(height)
    opacity: root.enabled ? 1 : 0.38
    scale: root.pressed ? 0.94 : 1

    Accessible.role: Accessible.Button
    Accessible.name: root.icon

    Behavior on scale {
        enabled: Motion.exit.duration > 0
        NumberAnimation {
            duration: Motion.exit.duration / 2
            easing.type: Easing.OutCubic
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Icons.font
        font.pixelSize: Type.iconSize("body") + (root.size === "s" ? -1 : 2)
        color: {
            const k = KitStates.ink(root.look);
            return k === "onAccent" ? Type.onAccent : (k === "accent" ? Type.accent : Type.text);
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
