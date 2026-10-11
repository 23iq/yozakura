pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "StageModel.js" as StageModel

// NEXT on the stage home, the right column's main block: what comes next
// (StageModel.nextRows: the running Pomodoro, calendar events through
// khal, timers and reminders), as many rows as fit (at most four). The
// first row leads: its time (or a timer's countdown) large, the title and
// "in 40 min" beside it; the rest are quiet lines spread over the free
// height. Nothing coming: one calm centered line.
Group {
    id: root

    // CalendarEvents rows ({date, time, title}); [] without a source.
    property var events: []
    readonly property real leadH: leadProbe.implicitHeight
    readonly property real minSmallH: Space.chip
    readonly property int capacity: Math.max(1, Math.min(4, 1 + Math.floor((root.bodyHeight - root.leadH - Space.s) / root.minSmallH)))
    readonly property var rows: StageModel.nextRows({
        "events": root.events,
        "timers": TimersService.timers,
        "reminders": TimersService.reminders,
        "now": TimersService.now
    }, root.capacity)
    readonly property real smallH: Math.min(root.minSmallH * 1.4, Math.max(root.minSmallH, (root.bodyHeight - root.leadH - Space.s) / Math.max(1, root.rows.length - 1)))
    readonly property real minimumHeight: root.chrome + root.leadH
    readonly property real smallTimeW: smallProbe.implicitWidth + Space.l

    function timeText(row: var): string {
        if (row.kind !== "event")
            return StageModel.clock(row.leftMs);
        if (row.allDay)
            return I18n.t("dashboard.stage.all_day");
        if (row.today)
            return row.time;
        return Qt.locale(I18n.resolvedLanguage).toString(new Date(row.at), "ddd") + " " + row.time;
    }

    function kindName(row: var): string {
        return I18n.t(row.kind === "pomodoro" ? "dashboard.stage.focus" : (row.kind === "reminder" ? "dashboard.stage.reminder" : "dashboard.stage.timer"));
    }

    function titleText(row: var): string {
        return row.title !== "" ? row.title : root.kindName(row);
    }

    function subText(row: var): string {
        if (row.kind !== "event")
            return I18n.t("dashboard.stage.remaining");
        const rel = StageModel.relativeIn(row.leftMs);
        if (!row.allDay && rel.key !== "")
            return I18n.t(rel.key).arg(rel.n);
        return Qt.locale(I18n.resolvedLanguage).toString(new Date(row.at), "dddd");
    }

    fill: true
    label: I18n.t("dashboard.stage.next")

    KitText {
        id: leadProbe
        visible: false
        role: "display"
        text: "00:00"
    }

    KitText {
        id: smallProbe
        visible: false
        role: "secondary"
        tabular: true
        text: "Wed 00:00"
    }

    Item {
        width: parent.width
        height: root.bodyHeight

        Column {
            width: parent.width
            visible: root.rows.length > 0

            Repeater {
                model: root.rows

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool lead: row.index === 0
                    readonly property bool timer: row.modelData.kind !== "event"

                    objectName: "nextRow"
                    width: parent.width
                    height: row.lead ? root.leadH + Space.s : root.smallH

                    KitText {
                        id: time
                        objectName: "nextTime"
                        width: row.lead ? implicitWidth : root.smallTimeW
                        role: row.lead ? "display" : "secondary"
                        tabular: true
                        elide: row.lead ? Text.ElideNone : Text.ElideRight
                        text: root.timeText(row.modelData)
                        y: row.lead ? 0 : (parent.height - height) / 2
                    }

                    Column {
                        x: row.lead ? time.width + Space.l : root.smallTimeW
                        width: parent.width - x
                        y: row.lead ? (root.leadH - height) / 2 : (parent.height - height) / 2
                        spacing: Space.xs / 2

                        Row {
                            width: parent.width
                            spacing: Space.s

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.timer && !row.lead
                                text: row.modelData.kind === "reminder" ? Icons.alarm : Icons.timer
                                font.family: Icons.font
                                font.pixelSize: Type.iconSize("caption")
                                color: Type.muted
                            }

                            KitText {
                                objectName: "nextTitle"
                                width: parent.width - (row.timer && !row.lead ? Type.iconSize("caption") + Space.s : 0)
                                role: row.lead ? "title" : "body"
                                elide: Text.ElideRight
                                text: root.titleText(row.modelData)
                            }
                        }

                        KitText {
                            objectName: "nextWhen"
                            width: parent.width
                            visible: row.lead
                            role: "secondary"
                            elide: Text.ElideRight
                            text: root.subText(row.modelData)
                        }
                    }
                }
            }
        }

        Column {
            objectName: "nextEmpty"
            anchors.centerIn: parent
            spacing: Space.s
            visible: root.rows.length === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.calendar
                font.family: Icons.font
                font.pixelSize: Type.size("display")
                color: Type.muted
                opacity: 0.6
            }

            KitText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "secondary"
                text: I18n.t("dashboard.stage.nothing_next")
            }
        }
    }
}
