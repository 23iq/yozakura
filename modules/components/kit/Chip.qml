import QtQuick
import qs.modules.theme
import qs.modules.components
import "KitStates.js" as KitStates
import qs.modules.components.kit

// Icon + label toggle. Inactive: the language's control box (Look);
// `active`: accent tint with accent icon and label (a solid accent fill in
// tiles). The hit area is at least 36 px tall.
StyledRect {
    id: root

    property string icon: ""
    property string text: ""
    property bool active: false
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property string look: KitStates.look(root.active && Look.solidActive, root.active, root.hovered && root.enabled)
    readonly property bool boxed: Look.boxedControls && (root.look === "normal" || root.look === "hover")
    readonly property color ink: {
        const k = KitStates.ink(root.look);
        return k === "accentInk" ? Type.accentInk : (k === "accent" ? Type.accent : Type.text);
    }

    signal clicked

    implicitHeight: Space.chip
    implicitWidth: row.implicitWidth + Space.m * 2
    variant: KitStates.variant(root.look, "common")
    backgroundOpacity: root.boxed ? 0 : KitStates.opacity(root.look, root.hovered)
    enableBorder: !root.boxed && !root.active
    radius: Look.chipRadius(height)
    opacity: root.enabled ? 1 : 0.38

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.active

    ControlBox {
        shown: root.boxed
        radius: root.radius
        hovered: root.look === "hover"
    }

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
            font.weight: root.active ? Look.activeLabelWeight : Look.labelWeight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -Math.max(0, (Space.controlS - root.height) / 2)
        anchors.bottomMargin: anchors.topMargin
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
