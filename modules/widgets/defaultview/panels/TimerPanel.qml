import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../services/timers/TimerFormat.js" as TimerFormat

// Timers segment panel: every timer (pause/resume, +1 min, reset, cancel,
// stop/snooze when ringing), the stopwatch with laps and the reminders;
// title actions: focus mode, stopwatch, new timer (opens the hub input).
NotchPanel {
    id: panel

    implicitHeight: panel.topPadding + group.implicitHeight + panel.padding

    Group {
        id: group
        x: panel.padding
        y: panel.topPadding
        width: parent.width - panel.padding * 2

        NotchPanelTitle {
            width: parent.width
            text: I18n.t("activities.timers")
            summary: FocusMode.active ? I18n.t("focus.left", TimerFormat.compact(FocusMode.leftMs)) : ""

            IconButton {
                objectName: "focusToggle"
                size: "s"
                active: FocusMode.active
                icon: Icons.brain
                Accessible.name: FocusMode.active ? I18n.t("focus.stop") : I18n.t("focus.start_for", FocusMode.defaultMinutes)
                onClicked: FocusMode.toggle(0)
            }
            IconButton {
                objectName: "stopwatchStart"
                size: "s"
                visible: !TimersService.stopwatchActive
                icon: Icons.watch
                Accessible.name: I18n.t("timers.stopwatch_start")
                onClicked: TimersService.stopwatchAction("start")
            }
            IconButton {
                objectName: "timerNew"
                size: "s"
                icon: Icons.plus
                Accessible.name: I18n.t("timers.new")
                onClicked: TimersService.openHub("timer", panel.screenName)
            }
        }

        TimerList {
            objectName: "timerList"
            width: parent.width
            height: implicitHeight
            unit: panel.unit
            maxRows: panel.maxRows > 0 ? panel.maxRows : 4
        }
    }
}
