import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import qs.modules.widgets.defaultview.activities

// Running timers (Pomodoro...): remaining time with a ring; clicking a row
// opens the timer's own UI.
NotchPanel {
    id: panel

    readonly property var timers: ActivityService.tasks.filter(a => a.source === "timers")

    implicitHeight: panel.padding * 2 + title.implicitHeight + panel.unit * 2 + list.implicitHeight

    NotchPanelTitle {
        id: title
        x: panel.padding
        y: panel.padding
        width: parent.width - panel.padding * 2
        unit: panel.unit
        icon: Icons.timer
        text: I18n.t("activities.timers")
    }

    NotchActivitiesSection {
        id: list
        x: panel.padding
        y: title.y + title.implicitHeight + panel.unit * 2
        width: parent.width - panel.padding * 2
        height: implicitHeight
        maxRows: panel.maxRows > 0 ? panel.maxRows : 4
        activities: panel.timers
        screenName: panel.screenName
    }
}
