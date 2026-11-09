import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.aicenter.common

// A level meter (context window, subscription limits): the kit's progress
// track with the fill in the level's `tone` (progress, warning, danger;
// the caller decides from its own thresholds).
//
//   LevelMeter { level: 0.62; tone: Type.progress; implicitWidth: Space.xxl }
ProgressLine {
    id: root

    property real level: 0
    property color tone: Type.progress

    // The kit fill stays empty: the toned fill below draws the level.
    value: 0

    // Fill of the meter.
    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.level))
        height: parent.height
        radius: parent.radius
        color: root.tone
        Behavior on width {
            enabled: BarLook.animDuration > 0
            NumberAnimation {
                duration: BarLook.animDuration / 2
                easing.type: Motion.morph.easing
            }
        }
    }
}
