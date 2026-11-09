import QtQuick
import qs.modules.theme

// The dimming layer behind a modal surface (overview, power menu): the
// theme's scrim colour at `strength`, faded in and out with `shown`; a
// click on it emits `clicked()` (close the surface; `dismissable: false`
// lets clicks through). `color` can take another ink role
// (Colors.background for a frosted wash).
Rectangle {
    id: root

    property bool shown: true
    property real strength: 0.5
    // false when the caller drives `strength` with its own animation
    property bool animated: true
    property bool dismissable: true

    signal clicked

    anchors.fill: parent
    color: Colors.scrim
    opacity: root.shown ? root.strength : 0

    Behavior on opacity {
        enabled: root.animated && Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.dismissable
        onClicked: root.clicked()
    }
}
