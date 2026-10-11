pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "StageModel.js" as StageModel

// NEXT on the stage home, the right column's main block: what comes next
// (StageModel.nextRows: the running Pomodoro, calendar events through
// khal, timers and reminders), as many rows as fit (at most four). The
// first one leads as a bold card (StageNextLead: its time or countdown
// large, an accent bar, the title and "in 40 min"); the rest are rows with
// an icon tile (StageNextRow). Nothing coming: one calm centered line.
Group {
    id: root

    // CalendarEvents rows ({date, time, title}); [] without a source.
    property var events: []
    readonly property real leadH: leadProbe.implicitHeight + Space.m * 2
    readonly property real rowH: Space.controlM
    readonly property int capacity: Math.max(1, Math.min(4, 1 + Math.floor((root.bodyHeight - root.leadH + 0.5) / (root.rowH + Space.xs))))
    readonly property var rows: StageModel.nextRows({
        "events": root.events,
        "timers": TimersService.timers,
        "reminders": TimersService.reminders,
        "now": TimersService.now
    }, root.capacity)
    // The rows share the free height (up to a quarter taller than rowH).
    readonly property real spreadH: Math.max(root.rowH, Math.min(root.rowH * 1.25, (root.bodyHeight - root.leadH) / Math.max(1, root.rows.length - 1) - Space.xs))
    readonly property real minimumHeight: root.chrome + root.leadH
    // Room for the lead and two rows (the host's preferred height).
    readonly property real naturalHeight: root.minimumHeight + 2 * (root.rowH + Space.xs)

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

    function glyph(row: var): string {
        return row.kind === "event" ? Icons.calendar : (row.kind === "reminder" ? Icons.alarm : Icons.timer);
    }

    fill: true
    implicitHeight: root.naturalHeight
    label: I18n.t("dashboard.stage.next")

    KitText {
        id: leadProbe
        visible: false
        role: "display"
        text: "00:00"
    }

    Item {
        width: parent.width
        height: root.bodyHeight

        Column {
            width: parent.width
            spacing: Space.xs
            visible: root.rows.length > 0

            Repeater {
                model: root.rows

                Loader {
                    id: slot
                    required property var modelData
                    required property int index

                    width: parent.width
                    sourceComponent: slot.index === 0 ? leadCard : smallRow

                    Component {
                        id: leadCard
                        StageNextLead {
                            objectName: "nextRow"
                            width: slot.width
                            height: root.leadH
                            time: root.timeText(slot.modelData)
                            title: root.titleText(slot.modelData)
                            when: root.subText(slot.modelData)
                            kind: root.kindName(slot.modelData) !== root.titleText(slot.modelData) ? root.kindName(slot.modelData) : ""
                            icon: root.glyph(slot.modelData)
                        }
                    }

                    Component {
                        id: smallRow
                        StageNextRow {
                            objectName: "nextRow"
                            width: slot.width
                            height: root.spreadH
                            time: root.timeText(slot.modelData)
                            title: root.titleText(slot.modelData)
                            when: slot.modelData.kind === "event" ? root.subText(slot.modelData) : root.kindName(slot.modelData)
                            icon: root.glyph(slot.modelData)
                        }
                    }
                }
            }
        }

        Column {
            objectName: "nextEmpty"
            anchors.centerIn: parent
            spacing: Space.m
            visible: root.rows.length === 0

            Art {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Space.controlL
                height: width
                icon: Icons.calendar
            }

            KitText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "secondary"
                text: I18n.t("dashboard.stage.nothing_next")
            }
        }
    }
}
