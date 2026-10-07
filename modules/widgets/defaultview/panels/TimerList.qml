pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt.labs.qmlmodels
import qs.modules.services
import qs.modules.components.kit

// Timers, the stopwatch (while used) and reminders of TimersService as one
// scrolling list (past ~`maxRows` rows). Delegates are keyed, so the
// per-second updates never recreate them. Empty: a hint line.
Item {
    id: list

    property int maxRows: 4
    property real unit: 4

    readonly property var rows: {
        const out = TimersService.timers.map(t => ({
                    "key": "timer:" + t.id,
                    "kind": "timer",
                    "ref": t
                }));
        if (TimersService.stopwatchActive)
            out.push({
                "key": "stopwatch",
                "kind": "stopwatch",
                "ref": null
            });
        TimersService.reminders.forEach(r => out.push({
                "key": "reminder:" + r.id,
                "kind": "reminder",
                "ref": r
            }));
        return out;
    }
    readonly property bool empty: list.rows.length === 0

    property var byKey: ({})
    ListModel {
        id: keyModel
    }

    function sync() {
        const map = {};
        for (const r of list.rows)
            map[r.key] = r;
        list.byKey = map;
        let same = keyModel.count === list.rows.length;
        for (let i = 0; same && i < list.rows.length; i++)
            same = keyModel.get(i).key === list.rows[i].key;
        if (same)
            return;
        keyModel.clear();
        for (const r of list.rows)
            keyModel.append({
                key: r.key,
                kind: r.kind
            });
    }
    onRowsChanged: list.sync()
    Component.onCompleted: list.sync()

    readonly property real rowEstimate: Space.rowHeight + Space.xs
    implicitHeight: list.empty ? emptyText.implicitHeight + list.unit * 2 : Math.min(view.contentHeight, list.rowEstimate * list.maxRows)

    KitText {
        id: emptyText
        objectName: "timerListEmpty"
        visible: list.empty
        width: parent.width
        y: list.unit
        role: "secondary"
        text: I18n.t("timers.empty")
        wrapMode: Text.WordWrap
    }

    ListView {
        id: view
        anchors.fill: parent
        visible: !list.empty
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        ScrollIndicator.vertical: ScrollIndicator {}
        model: keyModel
        spacing: Space.xs

        delegate: DelegateChooser {
            role: "kind"

            DelegateChoice {
                roleValue: "timer"
                delegate: TimerRow {
                    id: timerRow
                    required property string key
                    width: ListView.view.width
                    height: implicitHeight
                    unit: list.unit
                    timer: (list.byKey[timerRow.key] || {}).ref || null
                }
            }
            DelegateChoice {
                roleValue: "stopwatch"
                delegate: StopwatchRow {
                    width: ListView.view.width
                    height: implicitHeight
                    unit: list.unit
                }
            }
            DelegateChoice {
                roleValue: "reminder"
                delegate: ReminderRow {
                    id: reminderRow
                    required property string key
                    width: ListView.view.width
                    height: implicitHeight
                    unit: list.unit
                    reminder: (list.byKey[reminderRow.key] || {}).ref || null
                }
            }
        }
    }
}
