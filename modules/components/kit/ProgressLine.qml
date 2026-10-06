import QtQuick
import qs.modules.theme

// A thin progress line: track + accent fill (`value` 0..1).
Rectangle {
    id: root

    property real value: 0
    readonly property real fraction: Math.max(0, Math.min(1, root.value))

    implicitWidth: 160
    implicitHeight: Space.stroke
    radius: height / 2
    color: Type.track

    Rectangle {
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
}
