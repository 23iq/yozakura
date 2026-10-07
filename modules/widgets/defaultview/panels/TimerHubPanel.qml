import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../services/timers/TimerFormat.js" as TimerFormat

// Notch panel "timerHub" (NotchPanels.js: auto + modal), opened by
// TimersService.openHub(): binds (timer input, quick note, timers), the
// bar clock, the timers segment. Quick input with live preview on top
// (QuickInputField); in timer mode the timers/stopwatch/reminders below.
// Enter runs the line and closes; Esc / click outside closes.
NotchPanel {
    id: panel

    readonly property bool noteMode: TimersService.hubMode === "note"

    implicitHeight: panel.topPadding + group.implicitHeight + panel.padding

    onDismissed: TimersService.closeHub()
    onActiveFocusChanged: {
        if (panel.activeFocus)
            field.focusInput();
    }
    Keys.onEscapePressed: event => {
        TimersService.closeHub();
        event.accepted = true;
    }

    Group {
        id: group
        x: panel.padding
        y: panel.topPadding
        width: parent.width - panel.padding * 2

        NotchPanelTitle {
            width: parent.width
            text: panel.noteMode ? I18n.t("quicknote.title") : I18n.t("activities.timers")
            summary: !panel.noteMode && FocusMode.active ? I18n.t("focus.left", TimerFormat.compact(FocusMode.leftMs)) : ""

            IconButton {
                objectName: "hubFocus"
                size: "s"
                visible: !panel.noteMode
                active: FocusMode.active
                icon: Icons.brain
                Accessible.name: FocusMode.active ? I18n.t("focus.stop") : I18n.t("focus.start_for", FocusMode.defaultMinutes)
                onClicked: FocusMode.toggle(0)
            }
            IconButton {
                objectName: "hubStopwatch"
                size: "s"
                visible: !panel.noteMode && !TimersService.stopwatchActive
                icon: Icons.watch
                Accessible.name: I18n.t("timers.stopwatch_start")
                onClicked: TimersService.stopwatchAction("start")
            }
            IconButton {
                objectName: "hubMode"
                size: "s"
                icon: panel.noteMode ? Icons.timer : Icons.notePencil
                Accessible.name: panel.noteMode ? I18n.t("activities.timers") : I18n.t("quicknote.title")
                onClicked: {
                    TimersService.hubMode = panel.noteMode ? "timer" : "note";
                    field.focusInput();
                }
            }
        }

        QuickInputField {
            id: field
            objectName: "quickField"
            width: parent.width
            unit: panel.unit
            mode: TimersService.hubMode
            onDone: TimersService.closeHub()
        }

        TimerList {
            objectName: "timerList"
            visible: !panel.noteMode
            width: parent.width
            height: visible ? implicitHeight : 0
            unit: panel.unit
            maxRows: panel.maxRows > 0 ? panel.maxRows : 4
        }
    }
}
