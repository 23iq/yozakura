pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components
import qs.modules.corners
import qs.config

// The dock's background, filling the dock container: the default theme's
// edge-flowing surface (body + two concave screen corners, masked) or the
// floating theme's rounded rect. Also the shape of the dock's analytic
// shadow (PanelShadows): shadowRadii, cornerSize and fillAlpha.
Item {
    id: root

    property string position: "bottom"
    property bool isDefault: true
    property bool isFloating: false
    property bool unifiedEffectActive: false
    // Concave corner size along the edge (default theme), 0 without
    property int cornerSize: 0
    // Size of the dock's content (the body between the concave corners)
    property real contentWidth: 0
    property real contentHeight: 0

    readonly property bool isBottom: root.position === "bottom"
    readonly property bool isLeft: root.position === "left"
    readonly property bool isRight: root.position === "right"
    readonly property bool isVertical: root.isLeft || root.isRight

    // Corner radii of the body (tl, tr, br, bl), for the shadow
    readonly property vector4d shadowRadii: root.isDefault ? Qt.vector4d(dockBackground.topLeftRadius, dockBackground.topRightRadius, dockBackground.bottomRightRadius, dockBackground.bottomLeftRadius) : Qt.vector4d(dockBackgroundFloating.radius, dockBackgroundFloating.radius, dockBackgroundFloating.radius, dockBackgroundFloating.radius)
    // Fill colour x variant opacity: the shadow is as strong as a capture
    readonly property real fillAlpha: dockBackgroundFloating.rectOpacity * (dockBackgroundFloating.hasSolidColor ? dockBackgroundFloating.solidColor.a : 1)

    // Full background container with masking (default theme)
    Item {
        id: dockFullBgContainer
        visible: root.isDefault
        anchors.fill: parent

        // Background rect
        StyledRect {
            id: dockBackground
            anchors.fill: parent

            variant: "bg"
            glassSurface: "dock"
            anchorEdge: root.position
            // Shaped by dockMask (a corner style would replace that
            // layer effect and leave the fill transparent)
            cornerStyled: false
            // enableShadow: true
            enableBorder: false

            readonly property int fullRadius: Styling.radius(4)

            topLeftRadius: {
                if (root.isBottom)
                    return fullRadius;
                if (root.isLeft)
                    return 0;
                if (root.isRight)
                    return fullRadius;
                return fullRadius;
            }
            topRightRadius: {
                if (root.isBottom)
                    return fullRadius;
                if (root.isLeft)
                    return fullRadius;
                if (root.isRight)
                    return 0;
                return fullRadius;
            }
            bottomLeftRadius: {
                if (root.isBottom)
                    return 0;
                if (root.isLeft)
                    return 0;
                if (root.isRight)
                    return fullRadius;
                return fullRadius;
            }
            bottomRightRadius: {
                if (root.isBottom)
                    return 0;
                if (root.isLeft)
                    return fullRadius;
                if (root.isRight)
                    return 0;
                return fullRadius;
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: dockMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // Mask for the full background
    Item {
        id: dockMask
        visible: false
        anchors.fill: parent

        layer.enabled: true
        layer.smooth: true

        RoundCorner {
            id: corner1
            x: {
                if (root.isBottom)
                    return 0;
                if (root.isLeft)
                    return 0;
                if (root.isRight)
                    return parent.width - root.cornerSize;
                return 0;
            }
            y: {
                if (root.isBottom)
                    return parent.height - root.cornerSize;
                return 0;
            }
            size: Math.max(root.cornerSize, 1)
            corner: {
                if (root.isBottom)
                    return RoundCorner.CornerEnum.BottomRight;
                if (root.isLeft)
                    return RoundCorner.CornerEnum.BottomLeft;
                if (root.isRight)
                    return RoundCorner.CornerEnum.BottomRight;
                return RoundCorner.CornerEnum.BottomRight;
            }
            color: "white"
        }

        RoundCorner {
            id: corner2
            x: {
                if (root.isBottom)
                    return parent.width - root.cornerSize;
                if (root.isLeft)
                    return 0;
                if (root.isRight)
                    return parent.width - root.cornerSize;
                return 0;
            }
            y: parent.height - root.cornerSize
            size: Math.max(root.cornerSize, 1)
            corner: {
                if (root.isBottom)
                    return RoundCorner.CornerEnum.BottomLeft;
                if (root.isLeft)
                    return RoundCorner.CornerEnum.TopLeft;
                if (root.isRight)
                    return RoundCorner.CornerEnum.TopRight;
                return RoundCorner.CornerEnum.BottomLeft;
            }
            color: "white"
        }

        Rectangle {
            id: centerMask
            width: root.contentWidth
            height: root.contentHeight
            color: "white"

            x: root.isBottom ? root.cornerSize : 0
            y: root.isBottom ? 0 : root.cornerSize

            topLeftRadius: dockBackground.topLeftRadius
            topRightRadius: dockBackground.topRightRadius
            bottomLeftRadius: dockBackground.bottomLeftRadius
            bottomRightRadius: dockBackground.bottomRightRadius
        }
    }

    // Background for floating theme
    StyledRect {
        id: dockBackgroundFloating
        visible: root.isFloating
        anchors.fill: parent
        variant: "bg"
        glassSurface: "dock"
        anchorEdge: root.position
        // enableShadow: true
        radius: Styling.radius(4)
        enableBorder: !root.unifiedEffectActive
    }
}
