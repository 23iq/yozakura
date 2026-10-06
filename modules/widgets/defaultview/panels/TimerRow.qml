pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../services/timers/TimerFormat.js" as TimerFormat

// One timer (TimerFormat.timerRows shape) as a ListRow: a Ring with the
// share elapsed, the time left (tabular) over its name and state;
// pause/resume, +1 min, reset, cancel. A ringing timer offers +5 min
// (snooze) and Stop instead.
ListRow {
    id: row

    property var timer: null
    property real unit: Space.xs

    readonly property var t: row.timer || ({})
    readonly property bool ringing: !!row.t.ringing
    readonly property bool running: row.t.state === "running"

    tabular: true
    title: row.ringing ? I18n.t("activities.pomodoro_done") : TimerFormat.clock(row.t.leftMs || 0)
    subtitle: TimerFormat.timerTitle(row.t, I18n.t) + (row.t.state === "paused" ? " · " + I18n.t("timers.paused") : "")

    leading: Component {
        Ring {
            width: Space.controlS
            height: Space.controlS
            value: row.ringing ? 1 : (row.t.progress === undefined ? 0 : row.t.progress)
            color: row.running || row.ringing ? Type.accent : Type.muted

            Text {
                text: row.ringing ? Icons.alarm : (row.t.pomodoro ? Icons.countdown : Icons.timer)
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: row.running || row.ringing ? Type.accent : Type.muted
            }
        }
    }
    trailing: Component {
        Row {
            spacing: Space.xs

            IconButton {
                objectName: "timerSnooze"
                size: "s"
                visible: row.ringing
                icon: Icons.clockCounterClockwise
                Accessible.name: I18n.t("timers.action.snooze")
                onClicked: TimersService.add(row.t.id, "5m")
            }
            IconButton {
                objectName: "timerStop"
                size: "s"
                visible: row.ringing
                active: true
                icon: Icons.stop
                Accessible.name: I18n.t("timers.action.stop")
                onClicked: TimersService.dismiss(row.t.id)
            }
            IconButton {
                objectName: "timerToggle"
                size: "s"
                visible: !row.ringing
                icon: row.running ? Icons.pause : Icons.play
                Accessible.name: row.running ? I18n.t("timers.pause") : I18n.t("timers.resume")
                onClicked: TimersService.toggle(row.t.id)
            }
            IconButton {
                objectName: "timerPlus"
                size: "s"
                visible: !row.ringing
                icon: Icons.plus
                Accessible.name: I18n.t("timers.plus_minute")
                onClicked: TimersService.add(row.t.id, "+1m")
            }
            IconButton {
                objectName: "timerReset"
                size: "s"
                visible: !row.ringing
                icon: Icons.arrowCounterClockwise
                Accessible.name: I18n.t("timers.reset")
                onClicked: TimersService.reset(row.t.id)
            }
            IconButton {
                objectName: "timerCancel"
                size: "s"
                visible: !row.ringing
                icon: Icons.cancel
                Accessible.name: I18n.t("timers.cancel")
                onClicked: TimersService.cancel(row.t.id)
            }
        }
    }
}
