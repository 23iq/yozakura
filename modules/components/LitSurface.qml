import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// theme.lighting on one surface root (loaded by StyledRect while a light is
// on, under the surface's content and clipped by its shape): the night dim,
// the sun wash (one linear gradient from the lit side) and the 1 px lit
// edge, along the top and down the sun-facing side. Every value comes from
// Lighting; nothing here moves per frame.
Item {
    id: root

    // Corner radii of the surface [topLeft, topRight, bottomRight,
    // bottomLeft]: fills follow them (ClippingRectangle does not clip the
    // corners for every host) and the edges stop where the corners bend
    property var radii: [0, 0, 0, 0]
    readonly property real radius: Math.max(root.radii[0], root.radii[1], root.radii[2], root.radii[3])
    // The glass top highlight of the surface; the lit edge never goes below
    property real glassHighlight: 0

    readonly property real edge: Math.max(root.glassHighlight, Lighting.edgeStrength)
    readonly property color edgeColor: Lighting.edgeColor
    readonly property var light: Lighting.light
    // Where the light comes from, as a unit vector (opposite of the shadow)
    readonly property real fromX: root.light ? -root.light.dx : 0
    readonly property real fromY: root.light ? -root.light.dy : -1

    Rectangle {
        objectName: "litDim"
        anchors.fill: parent
        visible: Lighting.dimStrength > 0.001
        color: Qt.alpha(Lighting.dimColor, Lighting.dimStrength)
        topLeftRadius: root.radii[0]
        topRightRadius: root.radii[1]
        bottomRightRadius: root.radii[2]
        bottomLeftRadius: root.radii[3]
    }

    Shape {
        objectName: "litWash"
        anchors.fill: parent
        visible: Lighting.washStrength > 0.001

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: root.width / 2 + root.fromX * root.width / 2
                y1: root.height / 2 + root.fromY * root.height / 2
                x2: root.width / 2 - root.fromX * root.width * 0.3
                y2: root.height / 2 - root.fromY * root.height * 0.3
                GradientStop {
                    position: 0
                    color: Qt.alpha(Lighting.washColor, Lighting.washStrength)
                }
                GradientStop {
                    position: 0.45
                    color: Qt.alpha(Lighting.washColor, Lighting.washStrength * 0.35)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Lighting.washColor, 0)
                }
            }
            PathRectangle {
                width: root.width
                height: root.height
                topLeftRadius: root.radii[0]
                topRightRadius: root.radii[1]
                bottomRightRadius: root.radii[2]
                bottomLeftRadius: root.radii[3]
            }
        }
    }

    // Top edge, brightest where the light stands
    Rectangle {
        objectName: "litTop"
        visible: root.edge > 0.001
        x: root.radius
        width: Math.max(0, root.width - root.radius * 2)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.alpha(root.edgeColor, root.edge * 0.15)
            }
            GradientStop {
                position: Lighting.edgeCenter
                color: Qt.alpha(root.edgeColor, root.edge)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(root.edgeColor, root.edge * 0.15)
            }
        }
    }

    // Sun-facing side edge, fading downwards; only while the light is low
    Rectangle {
        id: side
        objectName: "litSide"
        readonly property real amount: root.edge * Math.min(1, Math.abs(Lighting.edgeSide) * 1.3)
        visible: amount > 0.02
        x: Lighting.edgeSide < 0 ? 0 : root.width - 1
        y: root.radius
        width: 1
        height: Math.max(0, root.height - root.radius * 2)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(root.edgeColor, side.amount)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(root.edgeColor, side.amount * 0.1)
            }
        }
    }
}
