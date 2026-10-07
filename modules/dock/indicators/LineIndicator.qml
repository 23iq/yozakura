pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme

// A thin line under the icon, split into one segment per window.
IndicatorBase {
    id: root

    size: 2
    spacing: 2

    readonly property real segment: Math.max(2, (cell * 0.6 - spacing * (info.n - 1)) / Math.max(1, info.n))

    mark: Rectangle {
        width: root.vertical ? root.across : root.segment
        height: root.vertical ? root.segment : root.across
        radius: Math.min(width, height) / 2
        color: root.tint

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }
}
