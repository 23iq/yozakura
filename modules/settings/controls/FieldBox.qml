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

    // A ghost language (ink: no box at rest): the raised fill of the kit's
    // big controls instead, so a field, a dropdown and a segmented read as
    // one family of boxes.
    readonly property bool ghost: root.boxed && Look.controlFill(false).a === 0 && Look.controlEdge.a === 0
    readonly property color edge: root.invalid ? Colors.error : (root.focused ? Type.accent : Type.track)

    Mark {
        visible: root.ghost
        anchors.fill: parent
        z: -1
        radius: root.radius
        color: Look.raisedFill(root.lit)
        Behavior on color {
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
            }
        }
    }

    // Editing / error edge.
    Mark {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: root.focused || root.invalid
        border.width: Space.hairline
        border.color: root.edge
    }
}
