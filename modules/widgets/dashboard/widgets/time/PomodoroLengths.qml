pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../../services/timers/TimerFormat.js" as TimerFormat

// The idle Pomodoro lengths (system.pomodoro.workTime / restTime): one row
// each, "Work Session · 25m" with -/+ 1 min IconButtons. Shared by the
// Pomodoro widget and the clock popup's Pomodoro row.
Column {
    id: root

    required property PomodoroModel pomodoro

    spacing: Space.s

    Repeater {
        model: [["workTime", "pomodoro.work_session"], ["restTime", "pomodoro.rest_session"]]

        Item {
            id: len
            required property var modelData
            width: root.width
            height: Space.controlS

            KitText {
                anchors.left: parent.left
                anchors.right: minus.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: I18n.t(len.modelData[1]) + " · " + TimerFormat.compact(root.pomodoro.cfg[len.modelData[0]] * 1000)
            }
            IconButton {
                id: minus
                anchors.right: plus.left
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.minus
                onClicked: root.pomodoro.adjust(len.modelData[0], -60)
            }
            IconButton {
                id: plus
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.plus
                onClicked: root.pomodoro.adjust(len.modelData[0], 60)
            }
        }
    }
}
