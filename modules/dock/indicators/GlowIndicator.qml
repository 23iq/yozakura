pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components.kit
import qs.config
import qs.modules.theme

// Round dots with a soft halo; the halo only shows on the focused app.
IndicatorBase {
    id: root

    size: 5

    mark: Item {
        width: root.size
        height: root.size

        Mark {
            anchors.centerIn: parent
            width: parent.width * 2.6
            height: width
            color: root.tint
            opacity: root.active ? 0.25 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.exit.duration
                }
            }
        }

        Mark {
            anchors.fill: parent
            color: root.tint
        }
    }
}
