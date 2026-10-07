import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import "../../components/kit/KitStates.js" as KitStates
import qs.modules.bar.look

// The box of one bar module (fills its parent, behind the content):
//   rest    `flat` modules have none. On a visible bar surface (strip, pill,
//           tab: BarLook.barSurface) the module is a piece of its group box:
//           nothing in ink, a frosted card in glass, a solid tile in tiles.
//           On a transparent bar the group box is the surface itself: the
//           theme's "bg" pill (plus a hairline in glass; tiles stay solid).
//           Classic keeps the "bg" pill exactly as configured.
//   hover   the language's control hover (Look.controlFill)
//   active  the kit's accent state: a tint with accent ink, a solid accent
//           fill in tiles (and classic)
// `startRadius` / `endRadius` join a run of modules into one group shape
// (BarLayout.edgeRadii); `ink` is the color for the module's content.
Item {
    id: root

    property bool vertical: false
    property real startRadius: 0
    property real endRadius: 0
    property bool flat: false
    property bool active: false
    property bool hovered: false
    // The "bg" pill casts the theme shadow
    property bool shadow: false

    readonly property string look: KitStates.look(root.active && (Look.solidActive || BarLook.classic), root.active, root.hovered)
    readonly property color ink: BarLook.ink(root.look)
    // "none" | "surface" (the theme's bg pill) | "group" (the language's box)
    readonly property string rest: BarLook.restLook(root.flat)

    readonly property real r1: BarLook.groupRadius(root.startRadius)
    readonly property real r2: BarLook.groupRadius(root.endRadius)
    // Flat modules have no group shape: states get a chip-like box
    readonly property real stateRadius: Look.chipRadius(Math.min(root.width, root.height))
    readonly property bool shaped: !root.flat && (root.r1 > 0 || root.r2 > 0)

    anchors.fill: parent
    z: -1

    // The theme's bar pill: classic, or the surface of a transparent bar
    StyledRect {
        objectName: "moduleSurface"
        anchors.fill: parent
        visible: root.rest === "surface"
        variant: "bg"
        enableShadow: root.shadow
        effectSurface: "bar"
        enableBorder: BarLook.classic
        topLeftRadius: root.r1
        topRightRadius: root.vertical ? root.r1 : root.r2
        bottomLeftRadius: root.vertical ? root.r2 : root.r1
        bottomRightRadius: root.r2
    }

    // The language's group box (or the hairline of a glass surface)
    Rectangle {
        objectName: "moduleGroupBox"
        anchors.fill: parent
        visible: (root.rest === "group" && Look.groupBoxed) || (root.rest === "surface" && !BarLook.classic && border.width > 0)
        color: root.rest === "group" ? Look.groupFill : "transparent"
        border.width: Look.groupOutline.a > 0 ? Space.hairline : 0
        border.color: Look.groupOutline
        topLeftRadius: root.r1
        topRightRadius: root.vertical ? root.r1 : root.r2
        bottomLeftRadius: root.vertical ? root.r2 : root.r1
        bottomRightRadius: root.r2

        // Light catching the top edge (glass)
        Rectangle {
            visible: Look.groupHighlight.a > 0
            x: Math.max(root.r1, root.vertical ? root.r1 : root.r2)
            y: parent.border.width
            width: parent.width - x * 2
            height: Space.hairline
            color: Look.groupHighlight
        }
    }

    // Hover
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.look === "hover" ? 1 : 0
        color: BarLook.classic ? Qt.rgba(Type.text.r, Type.text.g, Type.text.b, 0.1) : Look.controlFill(true)
        topLeftRadius: root.shaped ? root.r1 : root.stateRadius
        topRightRadius: root.shaped ? (root.vertical ? root.r1 : root.r2) : root.stateRadius
        bottomLeftRadius: root.shaped ? (root.vertical ? root.r2 : root.r1) : root.stateRadius
        bottomRightRadius: root.shaped ? root.r2 : root.stateRadius

        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    // Active: the accent state
    StyledRect {
        objectName: "moduleActive"
        anchors.fill: parent
        visible: root.look === "active" || root.look === "primary"
        variant: "primary"
        enableShadow: false
        enableBorder: false
        backgroundOpacity: KitStates.opacity(root.look, root.hovered)
        topLeftRadius: root.shaped ? root.r1 : root.stateRadius
        topRightRadius: root.shaped ? (root.vertical ? root.r1 : root.r2) : root.stateRadius
        bottomLeftRadius: root.shaped ? (root.vertical ? root.r2 : root.r1) : root.stateRadius
        bottomRightRadius: root.shaped ? root.r2 : root.stateRadius
    }
}
