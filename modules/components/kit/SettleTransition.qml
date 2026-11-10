import QtQuick

// The `displaced` and `move` transition of an animated list (a ListView over
// a KeyedListModel): glides an item to its new slot and finishes whatever an
// interrupted enter left half-way. A view stops an item's running transition
// where it stands when the next one starts (a second insert displaces it, a
// model move moves it), so a displaced transition of x,y alone leaves a card
// that was still fading / growing in at partial opacity and scale for good.
// `delay` holds the glide (a gap that closes once a leaving card is out).
//
// NumberAnimation, never Opacity/X/Y/ScaleAnimator: in a view transition the
// Animators' end values do not reach the item (a toast stayed invisible).
// Off while `duration` is 0, like the list's other transitions.
// It sets opacity and scale of the delegate root to 1: keep those at 1 on
// the root and put any dimming / press scale on an inner item.
Transition {
    id: root

    property int duration: 0
    property int easingType: Easing.OutCubic
    property int delay: 0

    enabled: root.duration > 0

    SequentialAnimation {
        PauseAnimation {
            duration: root.delay
        }
        ParallelAnimation {
            NumberAnimation {
                properties: "x,y"
                duration: root.duration
                easing.type: root.easingType
            }
            NumberAnimation {
                property: "opacity"
                to: 1
                duration: root.duration
                easing.type: root.easingType
            }
            NumberAnimation {
                property: "scale"
                to: 1
                duration: root.duration
                easing.type: root.easingType
            }
        }
    }
}
