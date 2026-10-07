import QtQuick
import qs.modules.services
import qs.modules.components.kit
import ".."

// Agenda bento widget: what is coming up, soonest first (AgendaRows:
// calendar events when a source provides them, otherwise the reminders and
// timers of TimersService; the Pomodoro has its own widget), as many lines
// as fit. Click opens the timers hub.
HostWidget {
    id: root

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.widget.agenda")

        KitText {
            objectName: "agendaEmpty"
            width: parent.width
            visible: rows.rows.length === 0
            role: "caption"
            wrapMode: Text.WordWrap
            maximumLineCount: Math.max(1, Math.floor(group.bodyHeight / (Type.size("caption") * 1.4)))
            text: I18n.t("bento.agenda.empty")
        }

        AgendaRows {
            id: rows
            width: parent.width
            limit: Math.max(1, Math.floor((group.bodyHeight + Space.m) / (rows.lineH + Space.m)))
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: TimersService.openHub("timer", "")
    }
}
