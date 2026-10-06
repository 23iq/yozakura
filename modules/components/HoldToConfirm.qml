import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// Hold-to-confirm ring for destructive actions (shutdown, reboot, logout).
// press() starts filling the ring over `holdMs` (Motion.emphasis x 1.33,
// at most 600 ms and never shorter than 400 ms, so it is a real hold even
// with animations off); release() before it is full cancels and winds the
// ring back. With focus, holding Enter/Space works the same way.
Item {
    id: root

    property color color: Colors.primary
    property color trackColor: Qt.rgba(color.r, color.g, color.b, 0.18)
    property real lineWidth: 3
    readonly property int holdMs: Math.min(600, Math.max(400, Math.round(Motion.emphasis.duration * 1.33)))
    readonly property bool holding: fill.running
    property real progress: 0

    signal confirmed
    signal cancelled

    function press() {
        if (fill.running)
            return;
        unwind.stop();
        fill.duration = Math.max(1, Math.round(root.holdMs * (1 - root.progress)));
        fill.start();
    }

    function release() {
        if (!fill.running)
            return;
        fill.stop();
        root.cancelled();
        unwind.duration = Math.round(Motion.emphasis.duration * 0.5 * root.progress);
        if (unwind.duration <= 0)
            root.progress = 0;
        else
            unwind.start();
    }

    NumberAnimation {
        id: fill
        target: root
        property: "progress"
        to: 1
        easing.type: Easing.Linear
        onFinished: {
            if (root.progress < 1)
                return;
            root.progress = 0;
            root.confirmed();
        }
    }

    NumberAnimation {
        id: unwind
        target: root
        property: "progress"
        to: 0
        easing.type: Easing.OutCubic
    }

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.press();
    }
    Keys.onReleased: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.release();
    }

    Shape {
        anchors.fill: parent
        visible: root.progress > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.max(0, Math.min(root.width, root.height) / 2 - root.lineWidth / 2)
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.max(0, Math.min(root.width, root.height) / 2 - root.lineWidth / 2)
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * root.progress
            }
        }
    }
}
