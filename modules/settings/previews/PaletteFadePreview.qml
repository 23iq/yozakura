pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.config
import qs.modules.settings.controls
import "../Ui.js" as Ui

// Swatches crossfading between two palettes at the live palette
// transition duration (what a wallpaper change looks like).
PreviewStage {
    id: root

    property var entry
    readonly property int duration: Config.theme.paletteTransitionDuration
    property bool flip: false
    readonly property var a: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.primaryContainer, Colors.surfaceContainerHighest]
    readonly property var b: [Colors.tertiary, Colors.primary, Colors.secondaryContainer, Colors.tertiaryContainer, Colors.surfaceBright]

    stageHeight: 104

    Timer {
        interval: Math.max(root.duration, 100) + 900
        running: root.visible
        repeat: true
        onTriggered: root.flip = !root.flip
    }

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 8
        spacing: 10

        Repeater {
            model: 5
            Rectangle {
                id: swatch
                required property int index
                width: 64
                height: 44
                radius: Math.min(Styling.radius(-2), 14)
                color: root.flip ? root.b[index] : root.a[index]
                Behavior on color {
                    enabled: root.duration > 0
                    ColorAnimation {
                        duration: root.duration
                        easing.type: Motion.morph.easing
                    }
                }
                border.width: 1
                border.color: Ui.alpha(Colors.outlineVariant, 0.6)
            }
        }
    }
}
