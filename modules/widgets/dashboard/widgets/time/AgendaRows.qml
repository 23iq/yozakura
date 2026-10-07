pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "AgendaModel.js" as AgendaModel
import "../../../../services/timers/TimerFormat.js" as TimerFormat

// The coming agenda items (AgendaModel.rows over TimersService, at most
// `limit`), one line each: a muted glyph, the title and the time on the
// right. Shared by the agenda widget and the clock popup.
Column {
    id: root

    property int limit: 0
    readonly property real lineH: Math.max(Type.iconSize("body"), Type.size("body") * 1.4)
    readonly property var rows: AgendaModel.rows({
        "events": null,
        "reminders": TimersService.reminders,
        "timers": TimersService.timers,
        "now": TimersService.now
    }, root.limit)

    function iconOf(row) {
        if (row.kind === "event")
            return Icons.calendar;
        if (row.kind === "reminder")
            return Icons.alarm;
        return Icons.timer;
    }

    spacing: Space.m

    Repeater {
        model: root.rows

        Item {
            id: row
            required property var modelData
            objectName: "agendaRow"
            width: root.width
            height: root.lineH

            Text {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                text: root.iconOf(row.modelData)
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: row.modelData.ringing ? Colors.error : Type.muted
            }
            KitText {
                anchors.left: glyph.right
                anchors.leftMargin: Space.s
                anchors.right: when.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                text: row.modelData.title !== "" ? row.modelData.title : I18n.t(row.modelData.kind === "reminder" ? "timers.reminder" : "timers.timer")
            }
            KitText {
                id: when
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                tabular: true
                opacity: row.modelData.paused ? 0.6 : 1
                text: row.modelData.kind === "timer" ? TimerFormat.clock(row.modelData.leftMs) : TimerFormat.timeOfDay(row.modelData.at, TimersService.use12h)
            }
        }
    }
}
