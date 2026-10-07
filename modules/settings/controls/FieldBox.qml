import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// The box behind a settings field (text, number, path, font): the kit's
// control box (Look) at rest, the hover look while hovered or focused, a
// hairline accent edge while editing and an error edge when `invalid`;
// in a ghost language (ink) a hairline under the field carries them.
// Children sit on top; set `hovered` / `focused` from the field.
StyledRect {
    id: root

    property bool hovered: false
    property bool focused: false
    property bool invalid: false
    readonly property bool lit: root.hovered || root.focused
    readonly property bool boxed: Look.boxedControls

    implicitHeight: Space.chip
    variant: root.lit ? "focus" : "common"
    backgroundOpacity: root.boxed ? 0 : -1
    enableBorder: !root.boxed && !root.focused && !root.invalid
    radius: Look.chipRadius(height)

    ControlBox {
        shown: root.boxed
        radius: root.radius
        hovered: root.lit
    }

    // A ghost language (ink: no box at rest) underlines the field instead.
    readonly property bool ghost: root.boxed && Look.controlFill(false).a === 0 && Look.controlEdge.a === 0
    readonly property color edge: root.invalid ? Colors.error : (root.focused ? Type.accent : Type.track)

    Rectangle {
        visible: root.ghost
        anchors.bottom: parent.bottom
        width: parent.width
        height: Space.hairline
        color: root.edge
    }

    // Editing / error edge.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: !root.ghost && (root.focused || root.invalid)
        border.width: Space.hairline
        border.color: root.edge
    }
}
