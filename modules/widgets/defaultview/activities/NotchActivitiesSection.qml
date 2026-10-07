pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt.labs.qmlmodels
import qs.modules.components.kit
import qs.modules.services.activities
import "NotchActivities.js" as NotchActivities

// Scrolling list used by the notch panels: activity rows (recording,
// timers, privacy) then transfers grouped by source. Scrolls past ~`maxRows`
// rows. Delegates are keyed so per-second updates never recreate them.
Item {
    id: section

    property string screenName: ""
    property int maxRows: 6
    // Inputs: ActivityModel activities and TransferModel transfers
    property var activities: []
    property var transfers: []
    // Show source group headers above transfers
    property bool groupHeaders: true

    readonly property var rows: NotchActivities.rows(section.activities, section.transfers).filter(r => section.groupHeaders || r.kind !== "header")

    // key -> row object; delegates read through it
    property var byKey: ({})
    ListModel {
        id: keyModel
    }

    function sync() {
        const map = {};
        for (const r of section.rows)
            map[r.key] = r;
        section.byKey = map;
        let same = keyModel.count === section.rows.length;
        for (let i = 0; same && i < section.rows.length; i++)
            same = keyModel.get(i).key === section.rows[i].key;
        if (same)
            return;
        keyModel.clear();
        for (const r of section.rows)
            keyModel.append({
                key: r.key,
                kind: r.kind
            });
    }
    onRowsChanged: section.sync()
    Component.onCompleted: section.sync()

    readonly property real rowEstimate: Space.rowHeight + Space.s
    implicitHeight: Math.min(list.contentHeight, section.rowEstimate * section.maxRows)

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        ScrollIndicator.vertical: ScrollIndicator {}
        model: keyModel
        spacing: Space.xs

        delegate: DelegateChooser {
            role: "kind"

            DelegateChoice {
                roleValue: "header"
                delegate: Item {
                    id: headerRow
                    required property string key
                    readonly property var entry: section.byKey[headerRow.key] || null
                    width: ListView.view.width
                    implicitHeight: label.implicitHeight + Space.s
                    height: implicitHeight
                    SectionLabel {
                        id: label
                        anchors.left: parent.left
                        anchors.leftMargin: Space.s
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: headerRow.entry ? headerRow.entry.label : ""
                    }
                }
            }
            DelegateChoice {
                roleValue: "transfer"
                delegate: NotchTransferRow {
                    id: transferRow
                    required property string key
                    width: ListView.view.width
                    height: implicitHeight
                    transfer: (section.byKey[transferRow.key] || {}).ref || null
                    showSpeed: ActivityService.showSpeed
                }
            }
            DelegateChoice {
                roleValue: "activity"
                delegate: NotchActivityRow {
                    id: activityRow
                    required property string key
                    width: ListView.view.width
                    height: implicitHeight
                    activity: (section.byKey[activityRow.key] || {}).ref || null
                    screenName: section.screenName
                }
            }
        }
    }
}
