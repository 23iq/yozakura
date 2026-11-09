import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.config

// Outline of the attached notch: one continuous stroke along the body and
// its two concave screen corners, drawn for a top or bottom `edge` (a side
// notch turns this item, see NotchSilhouette). A GPU path (Shape, curve
// renderer): a size change while the notch morphs updates the path, it
// never repaints and re-uploads a canvas texture.
Shape {
    id: root

    property string edge: "top"
    property int cornerSize: 0
    // Radius of the two corners facing the screen center
    property real radius: 0

    readonly property var borderData: Config.theme.srBg.border
    readonly property int borderWidth: borderData[1]
    readonly property color borderColor: Config.resolveColor(borderData[0])

    // Drawn for the top edge; the bottom edge is its mirror image
    readonly property real o: root.borderWidth / 2 // keep the stroke inside
    readonly property real c: root.cornerSize
    readonly property real r: Math.max(0, root.radius - root.o)
    readonly property real rawR: root.radius
    readonly property real yBottom: root.height - root.o
    readonly property real wCenter: root.width - root.c * 2

    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
        origin.y: root.height / 2
        yScale: root.edge === "bottom" ? -1 : 1
    }

    ShapePath {
        strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
        strokeWidth: root.borderWidth
        fillColor: "transparent"
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        startX: root.o
        startY: root.o
        // concave corner along the edge (left)
        PathArc {
            x: root.c
            y: root.c
            radiusX: Math.max(0, root.c - root.o)
            radiusY: Math.max(0, root.c - root.o)
            direction: PathArc.Clockwise
        }
        PathLine {
            x: root.c
            y: root.yBottom - (root.rawR > 0 ? root.r : 0)
        }
        // corners facing the screen center
        PathArc {
            x: root.c + (root.rawR > 0 ? root.r : 0)
            y: root.yBottom
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: root.c + root.wCenter - (root.rawR > 0 ? root.r : 0)
            y: root.yBottom
        }
        PathArc {
            x: root.c + root.wCenter
            y: root.yBottom - (root.rawR > 0 ? root.r : 0)
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: root.c + root.wCenter
            y: root.c
        }
        // concave corner along the edge (right)
        PathArc {
            x: root.width - root.o
            y: root.o
            radiusX: Math.max(0, root.c - root.o)
            radiusY: Math.max(0, root.c - root.o)
            direction: PathArc.Clockwise
        }
    }
}
