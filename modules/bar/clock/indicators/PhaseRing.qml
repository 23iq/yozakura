import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A small depleting kit Ring next to the time: the share of the phase
// left, in the phase colour (work: primary, break: tertiary) over a faint
// track of the same colour. Paused dims it; the alarm pulses it.
Ring {
    id: root

    required property var indicator

    objectName: "pomodoroRing"
    readonly property real progress: root.indicator.view.progress
    readonly property real size: Math.round(root.indicator.fontSize * 1.1)

    implicitWidth: root.size
    implicitHeight: root.size
    value: root.progress
    thickness: Math.max(2, Math.round(root.size / 6))
    color: root.indicator.phaseColor
    trackColor: Qt.alpha(root.indicator.phaseColor, 0.25)
    opacity: root.indicator.view.running || root.indicator.view.ringing ? 1 : 0.55

    Behavior on value {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
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
