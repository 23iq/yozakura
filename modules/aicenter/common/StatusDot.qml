pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config

// Session status: running (pulsing primary), waiting (warning), idle, exited.
Rectangle {
    id: root

    property string status: "idle"

    implicitWidth: 8
    implicitHeight: 8
    radius: 4
    color: status === "running" || status === "starting" ? Colors.primary : (status === "waiting" ? Colors.warning : (status === "exited" ? Colors.outline : Colors.success))

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
