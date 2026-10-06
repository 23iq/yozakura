pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Round dots with a soft halo; the halo only shows on the focused app.
IndicatorBase {
    id: root

    size: 5

    mark: Item {
        width: root.size
        height: root.size

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 2.6
            height: width
            radius: width / 2
            color: root.tint
            opacity: root.active ? 0.25 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.tint
        }
    }
}
