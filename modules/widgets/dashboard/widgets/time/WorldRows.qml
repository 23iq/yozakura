pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components.kit

// World clocks as rows ("city · offset" on the left, the time on the right)
// from WorldClockSource.rows, at most `limit` (0: all). Shared by the world
// clocks widget and the clock popup's World group.
Column {
    id: root

    property var rows: []
    property int limit: 0
    property bool showOffset: true
    readonly property real lineH: Type.size("body") * 1.5

    spacing: Space.m

    Repeater {
        model: root.limit > 0 ? root.rows.slice(0, root.limit) : root.rows

        Item {
            id: row
            required property var modelData
            width: root.width
            height: root.lineH

            KitText {
                anchors.left: parent.left
                anchors.right: time.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: row.modelData.label + (root.showOffset && row.modelData.offset !== "" ? " · " + row.modelData.offset : "") + (row.modelData.dayDelta > 0 ? " · +1" : (row.modelData.dayDelta < 0 ? " · −1" : ""))
            }
            KitText {
                id: time
                objectName: "worldClockTime"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                tabular: true
                text: row.modelData.time
            }
        }
    }
}
