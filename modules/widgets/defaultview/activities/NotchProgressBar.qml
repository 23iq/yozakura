import QtQuick
import qs.config
import qs.modules.theme

// Thin progress bar; a negative progress shows a sliding indeterminate
// segment (static when animations are off).
Item {
    id: bar

    property real progress: 0
    property color accent: Colors.primary
    property bool running: true

    readonly property bool indeterminate: progress < 0
    implicitHeight: Math.max(3, Math.round(Styling.fontSize(-4) / 3))

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Colors.overBackground
        opacity: 0.12
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            radius: height / 2
            color: bar.accent
            width: bar.indeterminate ? parent.width * 0.3 : parent.width * Math.max(0, Math.min(1, bar.progress))
            x: bar.indeterminate ? bar.slide * (parent.width * 1.3) - parent.width * 0.3 : 0
            Behavior on width {
                enabled: !bar.indeterminate && Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    property real slide: 0.35
    NumberAnimation on slide {
        running: bar.indeterminate && bar.running && bar.visible && Config.animDuration > 0
        from: 0
        to: 1
        duration: 1400
        loops: Animation.Infinite
        easing.type: Easing.InOutSine
    }
}
