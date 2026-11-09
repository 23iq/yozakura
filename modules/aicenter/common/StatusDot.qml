pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Session status: running (pulsing accent), waiting (warning), idle, exited.
// A kit Ring stroked to a full disc in the status colour.
Ring {
    id: root

    property string status: "idle"

    implicitWidth: Space.s
    implicitHeight: Space.s
    value: 1
    thickness: Math.min(width, height) / 2
    color: status === "running" || status === "starting" ? Type.accent : (status === "waiting" ? Colors.warning : (status === "exited" ? Type.muted : Colors.success))
    trackColor: root.color

    SequentialAnimation on opacity {
        running: root.status === "running" || root.status === "starting" || root.status === "waiting"
        loops: Animation.Infinite
        onStopped: root.opacity = 1
        NumberAnimation {
            to: 0.35
            duration: 700
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: 700
            easing.type: Easing.InOutSine
        }
    }
}
