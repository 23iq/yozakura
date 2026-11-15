import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// One labelled row of the monitor details card: title + hint on the left,
// the control(s) on the right. Children land in the right column.
// `compact` (a narrow row card): the label over its control, no hint; a
// control as narrow as a switch stays on the label's line.
Item {
    id: row

    property string label: ""
    property string hint: ""
    property bool separator: true
    property bool compact: false
    // compact: the control sits on the label's line (a switch)
    property bool inline: false
    default property alias content: holder.data

    readonly property bool stackedLayout: row.compact && !row.inline
    implicitHeight: row.compact ? (row.stackedLayout ? textCol.implicitHeight + Space.xs + holder.childrenRect.height + Space.m : Math.max(textCol.implicitHeight, holder.childrenRect.height) + Space.m) : Math.max(textCol.implicitHeight, holder.childrenRect.height) + 28

    Divider {
        x: Look.rowInset
        width: parent.width - Look.rowInset * 2
        visible: Look.dividers && row.separator && !row.compact
    }

    Column {
        id: textCol
        x: row.compact ? 0 : Look.rowInset
        y: row.stackedLayout ? Space.xs : 0
        width: row.compact ? parent.width - (row.inline ? holder.width + Space.m : 0) : 190
        anchors.verticalCenter: row.stackedLayout ? undefined : parent.verticalCenter
        spacing: Space.xs

        KitText {
            width: parent.width
            text: row.label
            role: row.compact ? "secondary" : "body"
            font.weight: row.compact ? Type.weight("body") : Font.DemiBold
            wrapMode: Text.WordWrap
        }
        KitText {
            role: "caption"
            width: parent.width
            visible: row.hint !== "" && !row.compact
            text: row.hint
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: holder
        x: row.compact ? (row.inline ? parent.width - width : 0) : 230
        y: row.stackedLayout ? textCol.y + textCol.implicitHeight + Space.xs : 0
        width: row.compact ? (row.inline ? Space.controlL : parent.width) : parent.width - 250
        height: childrenRect.height
        anchors.verticalCenter: row.stackedLayout ? undefined : parent.verticalCenter
    }
}
