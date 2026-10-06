import QtQuick
import qs.modules.theme
import qs.config
import "../settings/Ui.js" as Ui

// Thin rounded progress bar. `percent` < 0 (unknown) slides a soft
// segment back and forth instead of filling.
Rectangle {
    id: root

    property int percent: -1
    property color accent: Colors.primary
    readonly property bool indeterminate: root.percent < 0

    implicitHeight: 6
    radius: height / 2
    color: Ui.alpha(root.accent, 0.16)
    clip: true

    Rectangle {
        id: fill
        visible: !root.indeterminate && root.percent > 0
        height: parent.height
        radius: parent.radius
        width: Math.max(parent.height, parent.width * Math.min(100, Math.max(0, root.percent)) / 100)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ui.mix(root.accent, Colors.tertiary, 0.35)
            }
            GradientStop {
                position: 1
                color: root.accent
            }
        }
        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: runner
        visible: root.indeterminate
        width: parent.width * 0.35
        height: parent.height
        radius: parent.radius
        color: root.accent
        opacity: 0.85

        SequentialAnimation on x {
            running: root.indeterminate && root.visible && Config.animDuration > 0
            loops: Animation.Infinite
            NumberAnimation {
                from: -runner.width
                to: root.width
                duration: 1300
                easing.type: Easing.InOutQuad
            }
        }
    }
}
