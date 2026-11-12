import QtQuick
import qs.modules.theme
import qs.modules.components
import "KitStates.js" as KitStates
import qs.modules.components.kit

// Icon + label toggle. Inactive: the language's control box (Look);
// `active`: accent tint with accent icon and label (a solid accent fill in
// tiles); `primary`: the one filled accent action of a surface (a text
// button). The hit area is at least 36 px tall. `showLabel: false` keeps
// only the icon (crowded rows); fullWidth / compactWidth are the widths
// with and without the label, for layouts that decide it.
// Pickers and attachments: `image` (a logo) instead of the icon, a
// `trailingIcon` (a menu caret) or `closable` (an x -> closeClicked()),
// `mono` labels, `maxLabelWidth` (> 0: the label elides in the middle).
// `quiet`: no box at rest (a toolbar of chips), `danger`: a destructive or
// failing state (error tint), `dense`: the short height of inline pills.
// `focusable`: reachable by Tab (Enter / Space click, a fading focus ring).
StyledRect {
    id: root

    property string icon: ""
    property string text: ""
    property url image: ""
    property string trailingIcon: ""
    property bool closable: false
    property bool mono: false
    property real maxLabelWidth: 0
    property bool active: false
    property bool primary: false
    property bool quiet: false
    property bool danger: false
    property bool dense: false
    property bool highlighted: false
    property bool showLabel: true
    property bool focusable: false
    readonly property bool hasImage: root.image.toString() !== ""
    readonly property real compactWidth: lead.implicitWidth + Space.m * 2
    readonly property real fullWidth: lead.implicitWidth + (root.text !== "" ? Space.s + label.implicitWidth : 0) + Space.m * 2
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property string look: KitStates.look(root.primary || (root.active && Look.solidActive && !root.danger), root.active, root.hovered && root.enabled, root.danger)
    readonly property bool boxed: Look.boxedControls && !(root.quiet && root.look === "normal") && (root.look === "normal" || root.look === "hover")
    readonly property color ink: Type.inkColor(KitStates.ink(root.look))

    signal clicked
    signal closeClicked

    activeFocusOnTab: root.focusable && root.enabled
    Keys.onPressed: event => {
        if (root.focusable && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.clicked();
            event.accepted = true;
        }
    }

    implicitHeight: root.dense ? Space.chip - Space.s : Space.chip
    implicitWidth: row.implicitWidth + Space.m * 2
    variant: KitStates.variant(root.look, root.quiet ? "transparent" : "common")
    backgroundOpacity: root.boxed ? 0 : KitStates.opacity(root.look, root.hovered)
    enableBorder: !root.boxed && !root.active && !root.primary && !root.quiet
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

        Item {
            id: lead
            visible: root.icon !== "" || root.hasImage
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.hasImage ? Type.iconSize("secondary") : glyph.implicitWidth
            implicitHeight: Type.iconSize("secondary")

            Icon {
                id: glyph
                anchors.centerIn: parent
                visible: !root.hasImage
                icon: root.icon
                role: "secondary"
                color: root.ink
            }

            Image {
                anchors.fill: parent
                visible: root.hasImage
                source: root.image
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
            }
        }

        KitText {
            id: label
            visible: root.text !== "" && (root.showLabel || (root.icon === "" && !root.hasImage))
            anchors.verticalCenter: parent.verticalCenter
            width: root.maxLabelWidth > 0 ? Math.min(implicitWidth, root.maxLabelWidth) : implicitWidth
            role: "secondary"
            text: root.text
            color: root.ink
            elide: root.maxLabelWidth > 0 ? Text.ElideMiddle : Text.ElideRight
            font.family: root.mono ? Type.monoFont : Type.family("secondary")
            font.weight: root.active || root.primary ? Look.activeLabelWeight : Look.labelWeight
        }

        Icon {
            visible: root.trailingIcon !== "" && !root.closable
            anchors.verticalCenter: parent.verticalCenter
            icon: root.trailingIcon
            role: "caption"
            color: root.ink
            opacity: 0.7
        }

        Icon {
            id: closeGlyph
            objectName: "chipClose"
            visible: root.closable
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.cancel
            role: "caption"
            color: root.ink
            opacity: closeMouse.containsMouse ? 1 : 0.6
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

    // Over the chip's own area: the x closes instead of clicking.
    MouseArea {
        id: closeMouse
        visible: root.closable
        x: row.x + closeGlyph.x - Space.xs
        y: 0
        width: closeGlyph.width + Space.xs * 2
        height: root.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.closeClicked()
    }

    FocusRing {
        radius: root.radius + Space.stroke
        shown: root.focusable && root.activeFocus
    }
}
