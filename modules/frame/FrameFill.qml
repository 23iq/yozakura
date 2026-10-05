pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.components

// The screen frame's fill: everything outside a rounded rectangle hole.
// Drawn as four edge strips plus four small inner-corner pieces instead of
// a full-screen StyledRect behind a full-screen inverted mask, so nothing
// here is an offscreen layer the size of the screen. Every piece shows the
// same full-screen StyledRect through its own window (clip), so gradients
// line up exactly; only the corners use a mask, a radius-sized one with the
// same thresholds as before.
Item {
    id: root

    property real leftThickness: 0
    property real topThickness: 0
    property real rightThickness: 0
    property real bottomThickness: 0
    property real innerRadius: 0

    readonly property real holeX: root.leftThickness
    readonly property real holeY: root.topThickness
    readonly property real holeWidth: root.width - root.leftThickness - root.rightThickness
    readonly property real holeHeight: root.height - root.topThickness - root.bottomThickness
    readonly property bool hasHole: root.holeWidth > 0 && root.holeHeight > 0
    // Corner pieces never overlap each other or the strips
    readonly property real cornerSize: root.hasHole ? Math.ceil(Math.min(root.innerRadius, root.holeWidth / 2, root.holeHeight / 2)) : 0

    component FramePiece: Item {
        id: win
        clip: true
        visible: win.width > 0 && win.height > 0
        StyledRect {
            variant: "frame"
            x: -win.x
            y: -win.y
            width: root.width
            height: root.height
            radius: 0
            enableBorder: false
        }
    }

    // Without a hole the frame covers everything
    FramePiece {
        visible: !root.hasHole && root.width > 0 && root.height > 0
        width: root.width
        height: root.height
    }

    // Edge strips: top and bottom span the width, left and right the rest
    FramePiece {
        visible: root.hasHole && root.holeY > 0
        width: root.width
        height: root.holeY
    }
    FramePiece {
        visible: root.hasHole && root.bottomThickness > 0
        y: root.holeY + root.holeHeight
        width: root.width
        height: root.bottomThickness
    }
    FramePiece {
        visible: root.hasHole && root.holeX > 0
        y: root.holeY
        width: root.holeX
        height: root.holeHeight
    }
    FramePiece {
        visible: root.hasHole && root.rightThickness > 0
        x: root.holeX + root.holeWidth
        y: root.holeY
        width: root.rightThickness
        height: root.holeHeight
    }

    // Inner corners: the frame between the hole's rounded corner and its
    // bounding square, masked by the same rounded rectangle as before
    Repeater {
        model: root.cornerSize > 0 ? 4 : 0
        delegate: Item {
            id: corner
            required property int index
            readonly property bool atRight: corner.index === 1 || corner.index === 3
            readonly property bool atBottom: corner.index >= 2

            x: corner.atRight ? root.holeX + root.holeWidth - root.cornerSize : root.holeX
            y: corner.atBottom ? root.holeY + root.holeHeight - root.cornerSize : root.holeY
            width: root.cornerSize
            height: root.cornerSize

            Item {
                id: cornerFill
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: cornerMask
                    maskInverted: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                StyledRect {
                    variant: "frame"
                    x: -corner.x
                    y: -corner.y
                    width: root.width
                    height: root.height
                    radius: 0
                    enableBorder: false
                }
            }

            // The hole's rounded rectangle, seen through this corner
            Item {
                id: cornerMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    x: root.holeX - corner.x
                    y: root.holeY - corner.y
                    width: root.holeWidth
                    height: root.holeHeight
                    radius: root.innerRadius
                    color: "white"
                }
            }
        }
    }

    FrameLines {
        anchors.fill: parent
        holeX: root.holeX
        holeY: root.holeY
        holeWidth: root.holeWidth
        holeHeight: root.holeHeight
        innerRadius: root.innerRadius
        thickness: Math.min(root.leftThickness, root.topThickness, root.rightThickness, root.bottomThickness)
    }
}
