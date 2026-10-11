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
    readonly property real leadH: Space.controlL - Space.xs
    readonly property real rowH: Space.controlM
    readonly property real rowGap: Space.xs
    readonly property int capacity: Math.max(1, Math.min(4, 1 + Math.floor((root.bodyHeight - root.leadH + 0.5) / (root.rowH + root.rowGap))))
    readonly property var rows: StageModel.nextRows({
        "events": root.events,
        "timers": TimersService.timers,
        "reminders": TimersService.reminders,
        "now": TimersService.now
    }, root.capacity)
    // Rows by a stable key (the list animates additions and removals).
    readonly property var byKey: {
        const out = {};
        for (const r of root.rows)
            out[root.keyOf(r)] = r;
        return out;
    }
    readonly property real minimumHeight: root.chrome + root.leadH
    // Room for the lead and one row (the host's preferred height).
    readonly property real naturalHeight: root.minimumHeight + root.rowH + root.rowGap

    function keyOf(row: var): string {
        return row.kind + "|" + row.title + "|" + (row.kind === "event" ? row.at : "");
    }

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

    Item {
        width: parent.width
        height: root.bodyHeight

        ListView {
            id: list
            objectName: "nextList"
            anchors.fill: parent
            interactive: false
            spacing: root.rowGap
            visible: root.rows.length > 0
            model: KeyedListModel {
                keys: root.rows.map(r => root.keyOf(r))
            }

            delegate: Loader {
                id: slot
                required property string key
                required property int index
                readonly property var row: root.byKey[slot.key] ?? null
                width: ListView.view.width
                height: slot.index === 0 ? root.leadH : root.rowH
                active: slot.row !== null
                sourceComponent: slot.index === 0 ? leadCard : smallRow

                Component {
                    id: leadCard
                    StageNextLead {
                        objectName: "nextRow"
                        time: root.timeText(slot.row)
                        title: root.titleText(slot.row)
                        when: root.subText(slot.row)
                        kind: root.kindName(slot.row) !== root.titleText(slot.row) ? root.kindName(slot.row) : ""
                        icon: root.glyph(slot.row)
                    }
                }

                Component {
                    id: smallRow
                    StageNextRow {
                        objectName: "nextRow"
                        time: root.timeText(slot.row)
                        title: root.titleText(slot.row)
                        when: slot.row.kind === "event" ? root.subText(slot.row) : root.kindName(slot.row)
                        icon: root.glyph(slot.row)
                    }
                }
            }

            add: Transition {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.glide.duration
                }
                NumberAnimation {
                    property: "x"
                    from: Space.l
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            remove: Transition {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Motion.micro.duration
                }
            }
            displaced: Transition {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    properties: "x,y"
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
        }

        StageEmpty {
            objectName: "nextEmpty"
            anchors.centerIn: parent
            visible: root.rows.length === 0
            icon: Icons.calendar
            text: I18n.t("dashboard.stage.nothing_next")
        }
    }
}
