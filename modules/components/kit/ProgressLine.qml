import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "ProgressMotion.js" as ProgressMotion

// A thin progress line: track + accent fill (`value` 0..1). With
// `indeterminate` (unknown progress) a calm accent segment sweeps across
// the track instead; the sweep runs only while the line is visible and
// rests centered when motion is off.
Rectangle {
    id: root

    property real value: 0
    property bool indeterminate: false
    readonly property real fraction: Math.max(0, Math.min(1, root.value))
    readonly property int cycle: ProgressMotion.cycle(Motion.emphasis.duration)
    readonly property bool sweeping: sweep.running
    property real phase: 0

    implicitWidth: 160
    implicitHeight: Space.stroke
    radius: height / 2
    color: Type.track

    Rectangle {
        visible: !root.indeterminate
        width: parent.width * root.fraction
        height: parent.height
        radius: parent.radius
        color: Type.accent

        Behavior on width {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
    }

    Rectangle {
        readonly property var seg: ProgressMotion.segment(root.phase, root.width, root.cycle <= 0)
        visible: root.indeterminate
        x: seg.x
        width: seg.width
        height: parent.height
        radius: parent.radius
        color: Type.accent
    }

    NumberAnimation {
        id: sweep
        target: root
        property: "phase"
        from: 0
        to: 1
        duration: Math.max(1, root.cycle)
        easing.type: Easing.InOutSine
        loops: Animation.Infinite
        running: root.indeterminate && root.visible && root.cycle > 0
    }
}
