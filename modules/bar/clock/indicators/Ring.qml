import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// A small depleting ring next to the time: the share of the phase left,
// in the phase colour (work: primary, break: tertiary). Paused dims it;
// the alarm pulses it.
Item {
    id: root

    required property var indicator

    objectName: "pomodoroRing"
    readonly property real progress: indicator.view.progress
    readonly property real size: Math.round(indicator.fontSize * 1.1)
    readonly property real stroke: Math.max(2, Math.round(size / 6))

    implicitWidth: size
    implicitHeight: size
    opacity: indicator.view.running || indicator.view.ringing ? 1 : 0.55

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(root.indicator.phaseColor, 0.25)
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.stroke) / 2
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.indicator.phaseColor
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.stroke) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * root.progress
                Behavior on sweepAngle {
                    enabled: Motion.morph.duration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
    }

    SequentialAnimation on scale {
        running: root.indicator.view.ringing && Motion.emphasis.duration > 0
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation {
            to: 1.25
            duration: Motion.emphasis.duration / 2
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            to: 1
            duration: Motion.emphasis.duration / 2
            easing.type: Easing.InQuad
        }
    }
}
