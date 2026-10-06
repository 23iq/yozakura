pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import "AgendaModel.js" as AgendaModel
import "../../../../services/timers/TimerFormat.js" as TimerFormat

// Agenda bento widget: what is coming up, soonest first. Calendar events
// when a source provides them (none yet, see AgendaModel.js), otherwise the
// reminders and timers of TimersService (the Pomodoro has its own widget).
// Click opens the timers hub.
StyledRect {
    id: root

    property real cellW: Metrics.bentoCell
    property real cellH: Metrics.bentoCell
    property bool compact: false

    readonly property int capacity: Math.max(1, Math.floor((root.height - Metrics.spacing * 2 - header.height) / (Metrics.badgeHeight + Metrics.spacing / 2)))
    readonly property var rows: AgendaModel.rows({
        "events": null,
        "reminders": TimersService.reminders,
        "timers": TimersService.timers,
        "now": TimersService.now
    }, root.capacity)

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(4)

    function iconOf(row) {
        if (row.kind === "event")
            return Icons.calendar;
        if (row.kind === "reminder")
            return Icons.alarm;
        return Icons.timer;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacing
        spacing: Metrics.spacing / 2

        Text {
            id: header
            text: I18n.t("bento.widget.agenda")
            color: Colors.outline
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.bold: true
        }

        Text {
            objectName: "agendaEmpty"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.rows.length === 0
            text: I18n.t("bento.agenda.empty")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Colors.outline
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
        }

        Repeater {
            model: root.rows

            RowLayout {
                id: row
                required property var modelData
                objectName: "agendaRow"
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.badgeHeight
                spacing: Metrics.spacing / 2

                Text {
                    text: root.iconOf(row.modelData)
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: row.modelData.ringing ? Colors.error : Colors.primary
                }
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.title !== "" ? row.modelData.title : I18n.t(row.modelData.kind === "reminder" ? "timers.reminder" : "timers.timer")
                    elide: Text.ElideRight
                    color: Colors.overBackground
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                }
                Text {
                    text: row.modelData.kind === "timer" ? TimerFormat.clock(row.modelData.leftMs) : TimerFormat.timeOfDay(row.modelData.at, TimersService.use12h)
                    opacity: row.modelData.paused ? 0.6 : 1
                    color: Colors.overBackground
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.bold: true
                    font.features: {
                        "tnum": 1
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            visible: root.rows.length > 0
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: TimersService.openHub("timer", "")
    }
}
