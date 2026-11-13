import QtQuick
import QtQuick.Shapes
import qs.modules.components.kit

// A dashed rounded outline: a drop zone ("move here"), a place something
// could go. `color` the dash ink, `fill` a wash inside, `radius` the
// corners, `dash` the dash length in px.
Shape {
    id: root

    property color color: Type.accent
    property color fill: "transparent"
    property real radius: Space.s
    property real stroke: Space.hairline + 1
    property real dash: Space.xs

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.stroke
        fillColor: root.fill
        strokeStyle: ShapePath.DashLine
        dashPattern: [root.dash / Math.max(1, root.stroke), root.dash / Math.max(1, root.stroke)]
        PathRectangle {
            x: root.stroke / 2
            y: root.stroke / 2
            width: Math.max(0, root.width - root.stroke)
            height: Math.max(0, root.height - root.stroke)
            radius: Math.min(root.radius, Math.min(root.width, root.height) / 2)
        }
    }
}
