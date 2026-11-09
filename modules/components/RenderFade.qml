import QtQuick

// Opacity Behavior that runs on the render thread (OpacityAnimator), so a
// busy GUI thread never stalls a fade: `RenderFade on opacity { duration:
// ...; easingType: ... }`. Off while `duration` is 0 (animations off): an
// Animator of duration 0 never writes its end value back.
//
// The animated value is not seen by GUI-thread bindings until the fade
// ends; something that must fade along (a shadow drawn elsewhere) uses its
// own RenderFade with the same duration and easing, started by the same
// change, and they run in step.
Behavior {
    id: root

    property int duration: 0
    property int easingType: Easing.Linear
    readonly property bool running: fade.running

    enabled: root.duration > 0

    OpacityAnimator {
        id: fade
        duration: root.duration
        easing.type: root.easingType
    }
}
