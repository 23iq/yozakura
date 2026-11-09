import QtQuick
import qs.modules.shell.osd

// Fades its content in and slides it from `slide` (a unit direction) by
// `distance` px while `shown`, and back out when hidden, on the render
// thread (Animators): a busy GUI thread never stalls the motion. Durations
// and easings are the OSD's Motion tokens (enter / exit). `moving` holds
// while any part of the motion runs, so a window can stay up until the
// content has faded out. Sized by its parent (no anchors: x and y move).
Item {
    id: root

    property bool shown: false
    property point slide: Qt.point(0, 1)
    property real distance: 14
    readonly property bool moving: root.leaving || fade.running || slideX.running || slideY.running

    readonly property int duration: root.shown ? OsdMotion.enterMs : OsdMotion.exitMs
    readonly property int easing: root.shown ? OsdMotion.enterEasing : OsdMotion.exitEasing

    // Set the moment `shown` drops (before the animator reports running) and
    // held for the exit motion, so `moving` never blinks off in between
    property bool leaving: false
    onShownChanged: {
        root.leaving = !root.shown && root.duration > 0;
        if (root.leaving)
            leaveTimer.restart();
        else
            leaveTimer.stop();
    }
    Timer {
        id: leaveTimer
        interval: OsdMotion.exitMs + 32
        onTriggered: root.leaving = false
    }

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    x: root.shown ? 0 : root.slide.x * root.distance
    y: root.shown ? 0 : root.slide.y * root.distance
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
        // an Animator of duration 0 never writes its value back
        enabled: root.duration > 0
        OpacityAnimator {
            id: fade
            duration: root.duration
            easing.type: root.easing
        }
    }
    Behavior on x {
        // an Animator of duration 0 never writes its value back
        enabled: root.duration > 0
        XAnimator {
            id: slideX
            duration: root.duration
            easing.type: root.easing
        }
    }
    Behavior on y {
        // an Animator of duration 0 never writes its value back
        enabled: root.duration > 0
        YAnimator {
            id: slideY
            duration: root.duration
            easing.type: root.easing
        }
    }
}
