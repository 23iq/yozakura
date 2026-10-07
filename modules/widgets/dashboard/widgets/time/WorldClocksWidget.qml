pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.components.kit
import ".."

// World clocks bento widget: the zones of the bar world clocks module
// (WorldClockSource). A wide tile sets them side by side (label, time, the
// offset against local time), a narrow one lists them as "city · offset"
// rows with the time on the right; rows that do not fit are dropped.
HostWidget {
    id: root

    readonly property bool wide: root.width > root.height * 1.5
    readonly property var rows: source.rows

    WorldClockSource {
        id: source
        running: root.visible && root.active
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.widget.worldClocks")

        KitText {
            width: parent.width
            visible: root.rows.length === 0
            role: "caption"
            wrapMode: Text.WordWrap
            text: I18n.t("bento.worldClocks.empty")
        }

        // Side by side
        Row {
            visible: root.wide && root.rows.length > 0
            width: parent.width
            height: group.bodyHeight

            Repeater {
                model: root.wide ? root.rows : []

                Column {
                    id: cell
                    required property var modelData
                    width: parent.width / Math.max(1, root.rows.length)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.xs

                    KitText {
                        width: parent.width - Space.s
                        role: "secondary"
                        text: cell.modelData.label
                    }
                    KitText {
                        objectName: "worldClockTime"
                        role: "title"
                        tabular: true
                        text: cell.modelData.time
                    }
                    KitText {
                        width: parent.width - Space.s
                        visible: group.bodyHeight > Space.rowHeight * 1.4
                        role: "caption"
                        text: cell.modelData.offset + (cell.modelData.dayDelta > 0 ? " · +1" : (cell.modelData.dayDelta < 0 ? " · −1" : ""))
                    }
                }
            }
        }

        // Stacked rows
        WorldRows {
            id: list
            visible: !root.wide
            width: parent.width
            rows: root.rows
            showOffset: root.width > Space.rowHeight * 3
            limit: Math.max(1, Math.floor((group.bodyHeight + Space.m) / (list.lineH + Space.m)))
        }
    }
}
