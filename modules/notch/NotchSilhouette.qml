import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components
import qs.modules.corners
import qs.config
import "NotchShape.js" as NotchShape

// Background of the notch on any screen edge, sized by its parent:
//   attached  flows out of the screen edge with two concave corners along
//             it, masked, with one continuous outline;
//   island    a floating rounded surface.
// Radii come from NotchShape.radii (edge corners vs. center-facing ones).
// The concave-corner mask and the outline are drawn for a top/bottom edge
// and turned for a side edge (NotchShape.frame); the surface itself and
// the content above it are never rotated.
Item {
    id: root

    property string position: "top"
    property bool unifiedEffectActive: false
    // Something is open or notifications show: rounder outer corners
    property bool open: false
    // Notifications under the resting view: the island's edge corners stay
    // tight so the stack reads as attached to the edge
    property bool tightEdge: false
    // Concave screen corner size; 0 for the island
    property int cornerSize: 0

    readonly property bool attached: Config.notchTheme === "default"
    readonly property int smallRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
    readonly property int outerRadius: Config.roundness > 0 ? (open ? Config.roundness + 20 : Config.roundness + 4) : 0
    readonly property var radii: NotchShape.radii(position, attached ? 0 : (tightEdge ? smallRadius : outerRadius), outerRadius)
    readonly property var frame: NotchShape.frame(position, width, height)

    // Animated radii (screen space) and the animated outer radius (frame
    // space, for the mask and the outline)
    property real tl: radii.tl
    property real tr: radii.tr
    property real bl: radii.bl
    property real br: radii.br
    property real outer: outerRadius
    Behavior on tl {
        RadiusAnimation {}
    }
    Behavior on tr {
        RadiusAnimation {}
    }
    Behavior on bl {
        RadiusAnimation {}
    }
    Behavior on br {
        RadiusAnimation {}
    }
    Behavior on outer {
        RadiusAnimation {}
    }

    // Radii morph with the size (Motion.morph), never on a curve of their
    // own: a bouncier corner than the silhouette reads as a wobble
    component RadiusAnimation: NumberAnimation {
        duration: Config.animDuration > 0 ? Motion.morph.duration : 0
        easing.type: Motion.morph.easing
        easing.overshoot: Motion.morph.overshoot
    }

    // ── attached: edge-flowing surface, masked by body + concave corners ──
    StyledRect {
        id: attachedBg
        variant: "bg"
        glassSurface: "notch"
        // Shaped by attachedMask (a corner style would leave it transparent)
        cornerStyled: false
        visible: false // drawn through the mask below
        anchors.fill: parent
        enabled: false
        enableBorder: false // the outline canvas draws it
        animateRadius: false
        topLeftRadius: root.tl
        topRightRadius: root.tr
        bottomLeftRadius: root.bl
        bottomRightRadius: root.br
        layer.enabled: root.attached
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.attached
        source: attachedBg
        maskEnabled: true
        maskSource: attachedMask
        maskThresholdMin: 0.5
        maskThresholdMax: 1.0
        maskSpreadAtMin: 1.0
    }

    Item {
        id: attachedMask
        visible: false
        anchors.fill: parent
        layer.enabled: root.attached
        layer.smooth: true

        Item {
            id: maskFrame
            anchors.centerIn: parent
            width: root.frame.w
            height: root.frame.h
            rotation: root.frame.rotation
            readonly property bool topEdge: root.frame.edge === "top"

            RoundCorner {
                anchors.left: parent.left
                y: maskFrame.topEdge ? 0 : parent.height - height
                width: root.cornerSize
                height: width
                corner: maskFrame.topEdge ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.BottomRight
                size: Math.max(width, 1)
                color: "white"
            }
            Rectangle {
                x: root.cornerSize
                width: parent.width - root.cornerSize * 2
                height: parent.height
                color: "white"
                topLeftRadius: maskFrame.topEdge ? 0 : root.outer
                topRightRadius: maskFrame.topEdge ? 0 : root.outer
                bottomLeftRadius: maskFrame.topEdge ? root.outer : 0
                bottomRightRadius: maskFrame.topEdge ? root.outer : 0
            }
            RoundCorner {
                anchors.right: parent.right
                y: maskFrame.topEdge ? 0 : parent.height - height
                width: root.cornerSize
                height: width
                corner: maskFrame.topEdge ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.BottomLeft
                size: Math.max(width, 1)
                color: "white"
            }
        }
    }

    // ── island: floating surface ──
    StyledRect {
        id: islandBg
        variant: "bg"
        glassSurface: "notch"
        visible: !root.attached
        anchors.fill: parent
        clip: false
        enableBorder: !root.unifiedEffectActive
        animateRadius: false
        radius: root.outer
        topLeftRadius: root.tl
        topRightRadius: root.tr
        bottomLeftRadius: root.bl
        bottomRightRadius: root.br
    }

    // ── attached outline: one stroke around body and concave corners ──
    NotchOutline {
        anchors.centerIn: parent
        width: root.frame.w
        height: root.frame.h
        rotation: root.frame.rotation
        z: 5000
        edge: root.frame.edge
        cornerSize: root.cornerSize
        radius: root.outer
        visible: root.attached && borderWidth > 0 && !root.unifiedEffectActive
    }
}
