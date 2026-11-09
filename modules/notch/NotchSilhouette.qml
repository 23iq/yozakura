pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components
import qs.modules.corners
import qs.config
import "NotchShape.js" as NotchShape

// Background of the notch on any screen edge, sized by its parent:
//   attached  flows out of the screen edge with two concave corners along
//             it, with one continuous outline;
//   island    a floating rounded surface.
// Radii come from NotchShape.radii (edge corners vs. center-facing ones).
// The outline is drawn for a top/bottom edge and turned for a side edge
// (NotchShape.frame); the surface itself and the content above it are never
// rotated.
//
// Nothing here is a layer whose size follows the morph: the attached body
// is a plain rounded StyledRect and each concave corner a cornerSize piece
// masked by a cornerSize corner, so an animated size only moves pieces.
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
    readonly property bool alongX: !NotchShape.vertical(root.position)
    // Alpha of the surface (fill colour x variant opacity): the analytic
    // shadow (PanelShadows) is as strong as the captured one was
    readonly property real surfaceAlpha: islandBg.rectOpacity * (islandBg.hasSolidColor ? islandBg.solidColor.a : 1)

    // Animated radii (screen space) and the animated outer radius (frame
    // space, for the outline)
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

    // ── attached: edge-flowing surface: body + two concave corners ──
    StyledRect {
        id: attachedBody
        variant: "bg"
        glassSurface: "notch"
        // Shaped by its radii (a corner style would mask it with a layer)
        cornerStyled: false
        visible: root.attached
        enabled: false
        enableBorder: false // the outline draws it
        animateRadius: false
        x: root.alongX ? root.cornerSize : 0
        y: root.alongX ? 0 : root.cornerSize
        width: Math.max(0, root.alongX ? root.width - root.cornerSize * 2 : root.width)
        height: Math.max(0, root.alongX ? root.height : root.height - root.cornerSize * 2)
        topLeftRadius: root.tl
        topRightRadius: root.tr
        bottomLeftRadius: root.bl
        bottomRightRadius: root.br
    }

    // Concave corners at both ends along the edge, against it. Each shows
    // the silhouette-sized fill through its window (gradients line up with
    // the body, like FrameFill's pieces), masked by a fixed-size corner.
    Repeater {
        model: root.attached && root.cornerSize > 0 ? 2 : 0
        delegate: Item {
            id: fillet
            required property int index
            readonly property bool first: fillet.index === 0

            x: root.alongX ? (fillet.first ? 0 : root.width - root.cornerSize) : (root.position === "right" ? root.width - root.cornerSize : 0)
            y: root.alongX ? (root.position === "bottom" ? root.height - root.cornerSize : 0) : (fillet.first ? 0 : root.height - root.cornerSize)
            width: root.cornerSize
            height: root.cornerSize

            // The filled part sits against the edge, toward the body
            readonly property int fillCorner: {
                switch (root.position) {
                case "bottom":
                    return fillet.first ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.BottomLeft;
                case "left":
                    return fillet.first ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.TopLeft;
                case "right":
                    return fillet.first ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.TopRight;
                default:
                    return fillet.first ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.TopLeft;
                }
            }

            Item {
                anchors.fill: parent
                clip: true
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: filletMask
                    maskThresholdMin: 0.5
                    maskThresholdMax: 1.0
                    maskSpreadAtMin: 1.0
                }
                StyledRect {
                    variant: "bg"
                    glassSurface: "notch"
                    cornerStyled: false
                    enabled: false
                    enableBorder: false
                    animateRadius: false
                    x: -fillet.x
                    y: -fillet.y
                    width: root.width
                    height: root.height
                    radius: 0
                }
            }
            RoundCorner {
                id: filletMask
                visible: false
                anchors.fill: parent
                size: Math.max(root.cornerSize, 1)
                corner: fillet.fillCorner
                color: "white"
                layer.enabled: true
                layer.smooth: true
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
