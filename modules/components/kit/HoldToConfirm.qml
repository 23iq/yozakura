import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Hold-to-confirm for destructive actions (shutdown, reboot, logout): a
// kit Ring that fills around its target while held. press() starts filling
// over `holdMs` (Motion.emphasis x 1.33, at most 600 ms and never shorter
// than 400 ms, so it is a real hold even with animations off); release()
// before it is full cancels and winds the ring back. With focus, holding
// Enter/Space works the same way. The ring shows only while it moves.
Item {
    id: root

    property color color: Type.accent
    property real lineWidth: Space.stroke
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
        easing.type: Motion.morph.easing
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
        easing.type: Motion.morph.easing
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

    Ring {
        anchors.fill: parent
        visible: root.progress > 0
        value: root.progress
        thickness: root.lineWidth
        color: root.color
    }
}
