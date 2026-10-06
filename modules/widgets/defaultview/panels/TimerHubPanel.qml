import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.widgets.defaultview.activities
import "../../../services/timers/TimerFormat.js" as TimerFormat

// Notch panel "timerHub" (NotchPanels.js: auto + modal), opened by
// TimersService.openHub(): binds (timer input, quick note, timers), the
// bar clock, the timers segment. Quick input with live preview on top
// (QuickInputField); in timer mode the timers/stopwatch/reminders below.
// Enter runs the line and closes; Esc / click outside closes.
NotchPanel {
    id: panel

    readonly property bool noteMode: TimersService.hubMode === "note"

    implicitHeight: panel.padding * 2 + title.implicitHeight + panel.unit * 3 + field.implicitHeight + (list.visible ? panel.unit * 3 + list.implicitHeight : 0)

    onDismissed: TimersService.closeHub()
    onActiveFocusChanged: {
        if (panel.activeFocus)
            field.focusInput();
    }
    Keys.onEscapePressed: event => {
        TimersService.closeHub();
        event.accepted = true;
    }

    NotchPanelTitle {
        id: title
        x: panel.padding
        y: panel.padding
        width: parent.width - panel.padding * 2
        unit: panel.unit
        icon: panel.noteMode ? Icons.notePencil : Icons.timer
        text: panel.noteMode ? I18n.t("quicknote.title") : I18n.t("activities.timers")
        summary: !panel.noteMode && FocusMode.active ? I18n.t("focus.left", TimerFormat.compact(FocusMode.leftMs)) : ""

        NotchIconButton {
            objectName: "hubFocus"
            visible: !panel.noteMode
            icon: Icons.brain
            tone: FocusMode.active ? "primary" : "overBackground"
            tooltip: FocusMode.active ? I18n.t("focus.stop") : I18n.t("focus.start_for", FocusMode.defaultMinutes)
            onClicked: FocusMode.toggle(0)
        }
        NotchIconButton {
            objectName: "hubStopwatch"
            visible: !panel.noteMode && !TimersService.stopwatchActive
            icon: Icons.watch
            tooltip: I18n.t("timers.stopwatch_start")
            onClicked: TimersService.stopwatchAction("start")
        }
        NotchIconButton {
            objectName: "hubMode"
            icon: panel.noteMode ? Icons.timer : Icons.notePencil
            tooltip: panel.noteMode ? I18n.t("activities.timers") : I18n.t("quicknote.title")
            onClicked: {
                TimersService.hubMode = panel.noteMode ? "timer" : "note";
                field.focusInput();
            }
        }
    }

    QuickInputField {
        id: field
        objectName: "quickField"
        x: panel.padding
        y: title.y + title.implicitHeight + panel.unit * 3
        width: parent.width - panel.padding * 2
        unit: panel.unit
        mode: TimersService.hubMode
        onDone: TimersService.closeHub()
    }

    TimerList {
        id: list
        objectName: "timerList"
        visible: !panel.noteMode
        x: panel.padding
        y: field.y + field.implicitHeight + panel.unit * 3
        width: parent.width - panel.padding * 2
        height: implicitHeight
        unit: panel.unit
        maxRows: panel.maxRows > 0 ? panel.maxRows : 4
    }
}
