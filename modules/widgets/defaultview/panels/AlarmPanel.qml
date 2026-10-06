pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../services/timers/TimerFormat.js" as TimerFormat

// Notch panel "alarm" (NotchPanels.js: auto), open while a timer rings
// (system.timers.alarmPanel): a full Ring with the alarm glyph (pulsing),
// what finished and +5 min / Stop (the primary action). It goes away once
// nothing rings.
NotchPanel {
    id: panel

    readonly property var ringing: TimersService.ringingTimers
    readonly property var first: panel.ringing.length > 0 ? panel.ringing[0] : null
    readonly property bool pulse: Config.system && Config.system.timers ? Config.system.timers.pulseOnFinish !== false : true

    implicitHeight: panel.topPadding + group.implicitHeight + panel.padding

    Group {
        id: group
        x: panel.padding
        y: panel.topPadding
        width: parent.width - panel.padding * 2

        Item {
            width: parent.width
            height: Math.max(badge.height, texts.implicitHeight, buttons.implicitHeight)

            Ring {
                id: badge
                width: Space.controlM
                height: Space.controlM
                anchors.verticalCenter: parent.verticalCenter
                value: 1

                Text {
                    text: Icons.alarm
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("body")
                    color: Type.accent
                }

                SequentialAnimation on scale {
                    running: panel.pulse && panel.revealed && Config.animDuration > 0
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 1.1
                        duration: 520
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        to: 1
                        duration: 680
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Column {
                id: texts
                anchors.left: badge.right
                anchors.leftMargin: Space.m
                anchors.right: buttons.left
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                KitText {
                    width: parent.width
                    role: "title"
                    text: I18n.t("activities.pomodoro_done")
                }
                KitText {
                    objectName: "alarmNames"
                    width: parent.width
                    role: "secondary"
                    text: panel.ringing.map(t => TimerFormat.timerTitle(t, I18n.t)).join(", ")
                }
            }

            Row {
                id: buttons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s

                IconButton {
                    objectName: "alarmSnooze"
                    visible: panel.ringing.length === 1
                    icon: Icons.clockCounterClockwise
                    Accessible.name: I18n.t("timers.action.snooze")
                    onClicked: TimersService.add(panel.first.id, "5m")
                }
                IconButton {
                    objectName: "alarmStop"
                    primary: true
                    icon: Icons.stop
                    Accessible.name: panel.ringing.length > 1 ? I18n.t("timers.stop_all") : I18n.t("timers.action.stop")
                    onClicked: TimersService.dismiss(panel.ringing.length > 1 ? "" : panel.first.id)
                }
            }
        }
    }
}
