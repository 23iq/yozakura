pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Capsule dots, one per window (the original dock indicator).
IndicatorBase {
    id: root

    mark: Rectangle {
        width: root.vertical ? root.across : root.along
        height: root.vertical ? root.along : root.across
        radius: Math.min(width, height) / 2
        color: root.tint

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }
}
