import QtQuick
import QtQuick.Shapes
import qs.config
import qs.modules.theme

// Thin progress ring: a faint full track plus the `progress` arc (0..1),
// clockwise from 12 o'clock. A negative progress (unknown total) shows a
// spinning quarter arc instead.
Item {
    id: ring

    property real progress: 0
    property color color: "white"
    property color trackColor: Qt.rgba(color.r, color.g, color.b, 0.22)
    property real lineWidth: 2

    readonly property real radius: Math.max(0, Math.min(width, height) / 2 - lineWidth / 2)

    readonly property bool indeterminate: progress < 0
    property real shownProgress: indeterminate ? 0.28 : Math.max(0, Math.min(1, progress))
    Behavior on shownProgress {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.trackColor
            strokeWidth: ring.lineWidth
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.shownProgress > 0 ? ring.color : "transparent"
            strokeWidth: ring.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90 + (ring.indeterminate ? ring.spin : 0)
                sweepAngle: 360 * ring.shownProgress
            }
        }
    }

    property real spin: 0
    NumberAnimation on spin {
        running: ring.indeterminate && ring.visible && Config.animDuration > 0
        from: 0
        to: 360
        duration: 1100
        loops: Animation.Infinite
    }
}
