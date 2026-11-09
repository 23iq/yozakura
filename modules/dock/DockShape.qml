pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.components
import qs.modules.corners
import qs.modules.components.kit

// The default dock theme's shape: the "bg" surface glued to the screen
// edge, rounded away from it, with concave fillets (`cornerSize`) where it
// meets the edge. `position`: bottom | left | right. The corner radii are
// exposed for the outline (DockOutline).
Item {
    id: root

    property string position: "bottom"
    property int cornerSize: 0
    property real contentWidth: 0
    property real contentHeight: 0
    property int fullRadius: 0
    readonly property bool isBottom: root.position === "bottom"
    readonly property bool isLeft: root.position === "left"
    readonly property bool isRight: root.position === "right"
    readonly property real topLeftRadius: dockBackground.topLeftRadius
    readonly property real topRightRadius: dockBackground.topRightRadius
    readonly property real bottomLeftRadius: dockBackground.bottomLeftRadius
    readonly property real bottomRightRadius: dockBackground.bottomRightRadius

    Item {
        id: dockFullBgContainer
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

            readonly property int fullRadius: root.fullRadius

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

        Mark {
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
}
