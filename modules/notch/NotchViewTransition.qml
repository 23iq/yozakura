import QtQuick
import qs.config
import qs.modules.theme

// Exchange content at its natural size while the notch morphs around it.
// Opacity only, on the render thread (OpacityAnimator): a busy GUI thread
// (the incoming view being created) never stalls the fade.
Transition {
    id: root

    property bool entering: false

    SequentialAnimation {
        PropertyAction {
            property: "opacity"
            value: root.entering ? 0 : 1
        }
        PauseAnimation {
            duration: root.entering ? Config.animDuration / 4 : 0
        }
        OpacityAnimator {
            from: root.entering ? 0 : 1
            to: root.entering ? 1 : 0
            duration: root.entering ? Config.animDuration * 3 / 4 : Config.animDuration / 4
            easing.type: Motion.emphasis.easing
        }
        // The end value on the GUI thread too (an Animator of duration 0,
        // animations off, never writes it back)
        PropertyAction {
            property: "opacity"
            value: root.entering ? 1 : 0
        }
    }
}
