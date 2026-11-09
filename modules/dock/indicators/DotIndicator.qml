pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components.kit
import qs.config
import qs.modules.theme

// Capsule dots, one per window (the original dock indicator).
IndicatorBase {
    id: root

    mark: Mark {
        width: root.vertical ? root.across : root.along
        height: root.vertical ? root.along : root.across
        color: root.tint

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }
}
