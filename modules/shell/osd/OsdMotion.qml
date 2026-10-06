pragma Singleton
import QtQuick
import Quickshell
import qs.modules.theme

// Flat view of the Motion tokens the OSD uses (durations are 0 when
// animations are off). Reads each token group through `var`, so the styles
// bind plain ints and enums.
Singleton {
    id: root

    readonly property var _enter: Motion.enter
    readonly property var _exit: Motion.exit
    readonly property var _morph: Motion.morph

    readonly property int enterMs: root._enter.duration
    readonly property int enterEasing: root._enter.easing
    readonly property int exitMs: root._exit.duration
    readonly property int exitEasing: root._exit.easing
    readonly property int morphMs: root._morph.duration
    readonly property int morphEasing: root._morph.easing
    readonly property real morphOvershoot: root._morph.overshoot
    readonly property int delayMs: Motion.delay
}
