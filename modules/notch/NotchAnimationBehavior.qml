import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components

// Standard enter/leave motion of a view that opens in the notch (the
// dashboard): scale and fade on the render thread (ScaleAnimator /
// OpacityAnimator), so a busy GUI thread (the view being built while the
// notch morphs) never stalls them. The GUI-thread opacity does not follow
// the fade, so `visible` holds through the leave motion by itself.
Item {
    id: root

    // Shown (animated in) or hidden (animated out)
    property bool isVisible: false

    readonly property int duration: Config.animDuration > 0 ? Config.animDuration : 0
    // Set the moment the view hides and held for the leave motion
    property bool leaving: false

    scale: root.isVisible ? 1.0 : 0.8
    opacity: root.isVisible ? 1.0 : 0.0
    visible: root.isVisible || root.leaving

    onIsVisibleChanged: {
        root.leaving = !root.isVisible && root.duration > 0;
        if (root.leaving)
            leaveTimer.restart();
        else
            leaveTimer.stop();
    }
    Timer {
        id: leaveTimer
        interval: root.duration + 32
        onTriggered: root.leaving = false
    }

    Behavior on scale {
        // an Animator of duration 0 never writes its value back
        enabled: root.duration > 0
        ScaleAnimator {
            duration: root.duration
            easing.type: Motion.morph.easing
            easing.overshoot: 1.2
        }
    }

    RenderFade on opacity {
        duration: root.duration
        easingType: Motion.enter.easing
    }
}
