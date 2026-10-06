import QtQuick
import qs.modules.theme
import qs.modules.components

// A thin progress line along the clock button: under the time on a
// horizontal bar, down the inner side on a vertical one. It shrinks as the
// phase runs out, in the phase colour.
Item {
    id: root

    required property var indicator

    objectName: "pomodoroUnderline"
    readonly property real progress: indicator.view.progress
    readonly property real thick: Math.max(2, Math.round(indicator.fontSize / 7))
    readonly property real inset: Metrics.spacing

    StyledRect {
        id: track
        variant: "common"
        enableShadow: false
        opacity: 0.5
        radius: root.thick / 2
        x: root.indicator.vertical ? parent.width - root.thick - root.inset / 2 : root.inset
        y: root.indicator.vertical ? root.inset : parent.height - root.thick - root.inset / 2
        width: root.indicator.vertical ? root.thick : parent.width - 2 * root.inset
        height: root.indicator.vertical ? parent.height - 2 * root.inset : root.thick
    }

    Rectangle {
        objectName: "pomodoroUnderlineFill"
        x: track.x
        y: track.y
        radius: root.thick / 2
        color: root.indicator.phaseColor
        opacity: root.indicator.view.running || root.indicator.view.ringing ? 1 : 0.55
        width: root.indicator.vertical ? root.thick : track.width * root.progress
        height: root.indicator.vertical ? track.height * root.progress : root.thick

        Behavior on width {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on height {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
    }
}
