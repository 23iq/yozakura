pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.modules.components.kit

// A rotary knob: a matte cap with a pointer, inside a 270° value arc (the
// track in Type.track, the value in Type.progress: the live value is the
// only accent). `detents` > 0 snaps the value to that many steps and marks
// each with a tick around the cap; 0 turns smoothly by `step`. Drag up /
// right to turn it up (vertical and horizontal drags both count), the wheel
// and the arrow keys step it, Page Up / Down take ten steps, Home / End the
// ends. `interactive: false` makes it a display (a host owns the input).
// `moved(value)` on user changes; external changes glide in. Children sit
// on the cap (an icon). Square: the size is min(width, height).
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property int detents: 0
    property real step: root.detents > 0 ? (root.to - root.from) / root.detents : (root.to - root.from) / 20
    property bool interactive: true
    property bool highlighted: false
    property color color: Type.progress
    readonly property real fraction: root.to === root.from ? 0 : Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
    // The drawn fraction: eases after external changes, 1:1 while dragged.
    property real shown: root.fraction
    readonly property bool pressed: drag.pressed
    readonly property bool hovered: drag.containsMouse || root.highlighted
    readonly property real size: Math.min(root.width, root.height)
    readonly property real stroke: Math.max(2, Math.round(root.size * 0.06))
    readonly property real arcR: (root.size - root.stroke) / 2
    readonly property real capR: root.arcR * (root.detents > 0 ? 0.66 : 0.74)
    readonly property real startAngle: 135
    readonly property real sweep: 270
    default property alias content: face.data

    signal moved(real value)

    function snap(v: real): real {
        if (root.detents <= 0)
            return v;
        const s = (root.to - root.from) / root.detents;
        return root.from + Math.round((v - root.from) / s) * s;
    }

    function setValue(v: real) {
        const c = root.snap(Math.max(root.from, Math.min(root.to, v)));
        if (Math.abs(c - root.value) < 1e-6)
            return;
        root.value = c;
        root.moved(c);
    }

    function stepBy(n: int) {
        root.setValue(root.value + n * root.step);
    }

    implicitWidth: Space.controlL
    implicitHeight: Space.controlL
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.interactive && root.enabled

    Accessible.role: Accessible.Dial
    Accessible.name: Math.round(root.fraction * 100) + "%"

    Keys.onUpPressed: root.stepBy(1)
    Keys.onRightPressed: root.stepBy(1)
    Keys.onDownPressed: root.stepBy(-1)
    Keys.onLeftPressed: root.stepBy(-1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)
            root.stepBy(event.key === Qt.Key_PageUp ? 10 : -10);
        else if (event.key === Qt.Key_Home || event.key === Qt.Key_End)
            root.setValue(event.key === Qt.Key_Home ? root.from : root.to);
        else
            return;
        event.accepted = true;
    }

    Behavior on shown {
        enabled: Motion.glide.duration > 0 && !root.pressed
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    Item {
        id: dial
        width: root.size
        height: root.size
        anchors.centerIn: parent

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Type.track
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: root.arcR
                    radiusY: root.arcR
                    startAngle: root.startAngle
                    sweepAngle: root.sweep
                }
            }

            ShapePath {
                strokeColor: root.shown > 0.001 ? root.color : "transparent"
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: root.arcR
                    radiusY: root.arcR
                    startAngle: root.startAngle
                    sweepAngle: root.sweep * root.shown
                }
            }
        }

        // Detent ticks between the arc and the cap.
        Repeater {
            model: root.detents > 0 ? root.detents + 1 : 0

            Rectangle {
                id: tick
                required property int index
                readonly property real angle: (root.startAngle + root.sweep * tick.index / root.detents) * Math.PI / 180
                readonly property real r: (root.arcR - root.stroke / 2 + root.capR) / 2
                width: Math.max(2, Math.round(root.stroke * 0.6))
                height: width
                radius: width / 2
                x: dial.width / 2 + Math.cos(tick.angle) * tick.r - width / 2
                y: dial.height / 2 + Math.sin(tick.angle) * tick.r - height / 2
                color: tick.index / root.detents <= root.shown + 1e-6 ? Type.secondary : Type.track
            }
        }

        // The cap: a matte raised disc with a hairline edge and the pointer.
        Rectangle {
            id: cap
            objectName: "knobCap"
            width: root.capR * 2
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: Look.raisedFill(root.hovered)
            border.width: Space.hairline
            border.color: Look.controlEdge.a > 0 ? Look.controlEdge : Type.hairline

            // The pointer turns; the cap's content stays upright.
            Item {
                anchors.fill: parent
                rotation: root.startAngle + 90 + root.sweep * root.shown

                Rectangle {
                    objectName: "knobPointer"
                    width: root.stroke
                    height: root.capR * 0.36
                    radius: width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.capR * 0.12
                    color: Type.text
                }
            }

            Item {
                id: face
                anchors.centerIn: parent
                width: childrenRect.width
                height: childrenRect.height
            }
        }
    }

    FocusRing {
        radius: root.size / 2 + Space.stroke
        shown: root.activeFocus
    }

    MouseArea {
        id: drag
        property real startValue: 0
        property point start: Qt.point(0, 0)
        anchors.fill: parent
        enabled: root.interactive && root.enabled
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        preventStealing: true
        onPressed: m => {
            drag.start = Qt.point(m.x, m.y);
            drag.startValue = root.value;
            root.forceActiveFocus();
        }
        // One full turn per ~2.5 knob sizes of travel.
        onPositionChanged: m => {
            if (!drag.pressed)
                return;
            const travel = (drag.start.y - m.y) + (m.x - drag.start.x);
            root.setValue(drag.startValue + travel / (root.size * 2.5) * (root.to - root.from));
        }
        onWheel: w => root.stepBy((w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x) > 0 ? 1 : -1)
    }
}
