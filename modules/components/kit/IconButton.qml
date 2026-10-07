import QtQuick
import qs.modules.theme
import qs.modules.components
import "KitStates.js" as KitStates
import qs.modules.components.kit

// Icon button. Sizes "s" (36) / "m" (40) / "l" (64, a hero action). Rest and hover / `highlighted`
// are the language's control box (Look: a ghost in ink, translucent with a
// hairline in glass, a solid squarer tile in tiles), `active` an accent tint
// with an accent glyph (a solid accent fill in tiles), `primary` the one
// filled accent action of a surface.
StyledRect {
    id: root

    property string icon: ""
    property string size: "m"
    property bool active: false
    property bool primary: false
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property bool pressed: mouse.pressed
    readonly property string look: KitStates.look(root.primary || (root.active && Look.solidActive), root.active, root.hovered && root.enabled)
    readonly property bool boxed: Look.boxedControls && (root.look === "normal" || root.look === "hover")

    signal clicked

    implicitWidth: root.size === "s" ? Space.controlS : (root.size === "l" ? Space.controlL : Space.controlM)
    implicitHeight: implicitWidth
    variant: KitStates.variant(root.look, "common")
    backgroundOpacity: root.boxed ? 0 : KitStates.opacity(root.look, root.hovered)
    enableBorder: !root.boxed && (root.look === "normal" || root.look === "hover")
    radius: Look.buttonRadius(height)
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

    ControlBox {
        shown: root.boxed
        radius: root.radius
        hovered: root.look === "hover"
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Icons.font
        font.pixelSize: root.size === "l" ? Type.iconSize("title") + 4 : Type.iconSize("body") + (root.size === "s" ? -1 : 2)
        color: {
            const k = KitStates.ink(root.look);
            return k === "accentInk" ? Type.accentInk : (k === "accent" ? Type.accent : Type.text);
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
