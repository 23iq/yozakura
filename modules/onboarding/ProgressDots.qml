pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Step progress: one dot per step, the current one stretched into a pill.
// Dots of visited steps are clickable.
Row {
    id: root

    property int count: 0
    property int current: 0
    readonly property int dot: Space.px(6)

    signal picked(int index)

    spacing: Space.xs + Space.px(1)

    Repeater {
        model: root.count
        delegate: Rectangle {
            id: d
            required property int index
            readonly property bool active: index === root.current
            readonly property bool visited: index < root.current
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: active ? root.dot * 3.4 : root.dot
            height: root.dot
            radius: height / 2
            color: active || visited ? Type.progress : Type.track
            opacity: visited && !area.containsMouse ? 0.55 : 1

            Behavior on width {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on color {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -Space.xs
                enabled: d.visited
                hoverEnabled: true
                cursorShape: d.visited ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.picked(d.index)
            }
        }
    }
}
