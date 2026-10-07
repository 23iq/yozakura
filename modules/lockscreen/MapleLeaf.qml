import QtQuick
import QtQuick.Shapes

// One falling maple leaf for Petals.qml (theme.signatures.petalShape
// "leaf"): a five-lobed leaf drawn on a 24-unit grid and scaled to `size`.
Shape {
    id: root

    property real size: 12
    property color color

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillColor: root.color
        scale: Qt.size(root.size / 24, root.size / 24)

        PathSvg {
            path: "M12 1 L13.6 5.6 L16.4 4.2 L15.6 9 L20.8 7.4 L19.4 10.6 L23 12 L18.2 14.6 L19.2 17 L13.4 16.2 L12.8 23 L11.2 23 L10.6 16.2 L4.8 17 L5.8 14.6 L1 12 L4.6 10.6 L3.2 7.4 L8.4 9 L7.6 4.2 L10.4 5.6 Z"
        }
    }
}
