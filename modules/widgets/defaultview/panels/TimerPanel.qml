import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.widgets.defaultview.activities
import "../../../services/timers/TimerFormat.js" as TimerFormat

// Timers segment panel: every timer (pause/resume, +1 min, reset, cancel,
// stop/snooze when ringing), the stopwatch with laps and the reminders;
// title actions: focus mode, stopwatch, new timer (opens the hub input).
NotchPanel {
    id: panel

    implicitHeight: panel.padding * 2 + title.implicitHeight + panel.unit * 2 + list.implicitHeight

    NotchPanelTitle {
        id: title
        x: panel.padding
        y: panel.padding
        width: parent.width - panel.padding * 2
        unit: panel.unit
        icon: Icons.timer
        text: I18n.t("activities.timers")
        summary: FocusMode.active ? I18n.t("focus.left", TimerFormat.compact(FocusMode.leftMs)) : ""
        accent: TimersService.ringing > 0 ? Colors.error : Colors.primary

        NotchIconButton {
            objectName: "focusToggle"
            icon: Icons.brain
            tone: FocusMode.active ? "primary" : "overBackground"
            tooltip: FocusMode.active ? I18n.t("focus.stop") : I18n.t("focus.start_for", FocusMode.defaultMinutes)
            onClicked: FocusMode.toggle(0)
        }
        NotchIconButton {
            objectName: "stopwatchStart"
            visible: !TimersService.stopwatchActive
            icon: Icons.watch
            tooltip: I18n.t("timers.stopwatch_start")
            onClicked: TimersService.stopwatchAction("start")
        }
        NotchIconButton {
            objectName: "timerNew"
            icon: Icons.plus
            tooltip: I18n.t("timers.new")
            onClicked: TimersService.openHub("timer", panel.screenName)
        }
    }

    TimerList {
        id: list
        objectName: "timerList"
        x: panel.padding
        y: title.y + title.implicitHeight + panel.unit * 2
        width: parent.width - panel.padding * 2
        height: implicitHeight
        unit: panel.unit
        maxRows: panel.maxRows > 0 ? panel.maxRows : 4
    }
}
