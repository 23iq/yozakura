pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config
import "../settings/Ui.js" as Ui

// Step progress: one dot per step, the current one stretched into a pill.
// Dots of visited steps are clickable.
Row {
    id: root

    property int count: 0
    property int current: 0
    readonly property int dot: Math.max(6, Math.round(Styling.fontSize(-4) * 0.75))

    signal picked(int index)

    spacing: Math.round(dot * 0.8)

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
            color: active || visited ? Colors.primary : Ui.alpha(Colors.overBackground, 0.22)
            opacity: visited && !area.containsMouse ? 0.55 : 1

            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.morph.duration
                    easing.type: Motion.morph.easing
                }
            }
            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Motion.enter.duration
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -4
                enabled: d.visited
                hoverEnabled: true
                cursorShape: d.visited ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.picked(d.index)
            }
        }
    }
}
