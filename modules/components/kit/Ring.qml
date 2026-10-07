import QtQuick
import QtQuick.Shapes
import qs.modules.components.kit

// A progress ring (`value` 0..1) with its children centered inside
// (pomodoro time, hold-to-confirm glyph). Same stroke as the line controls.
Item {
    id: root

    property real value: 0
    property real thickness: Space.stroke
    property color color: Type.progress
    readonly property real fraction: Math.max(0, Math.min(1, root.value))
    readonly property real arcRadius: (Math.min(width, height) - root.thickness) / 2
    default property alias content: center.data

    implicitWidth: 64
    implicitHeight: 64

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Type.track
            strokeWidth: root.thickness
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.fraction > 0 ? root.color : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -90
                sweepAngle: 360 * root.fraction
            }
        }
    }

    Item {
        id: center
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
