import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The keyboard focus ring of a control: an accent outline just outside the
// parent's shape that fades in while `shown` (bind it to the control's
// activeFocus) and focus is in keyboard use (FocusState.keyboard). `radius` follows the control's radius (pass it). Same ring
// in every visual language.
Rectangle {
    id: root

    property bool shown: false

    anchors.fill: parent
    anchors.margins: -Space.stroke
    color: "transparent"
    border.width: Space.stroke - 1
    border.color: Type.accent
    opacity: root.shown && FocusState.keyboard ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.micro.duration
            easing.type: Motion.micro.easing
        }
    }
}
