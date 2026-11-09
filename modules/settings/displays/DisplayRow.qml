import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// One labelled row of the monitor details card: title + hint on the left,
// the control(s) on the right. Children land in the right column.
Item {
    id: row

    property string label: ""
    property string hint: ""
    property bool separator: true
    default property alias content: holder.data

    implicitHeight: Math.max(textCol.implicitHeight, holder.childrenRect.height) + 28

    Divider {
        x: Look.rowInset
        width: parent.width - Look.rowInset * 2
        visible: Look.dividers && (row.separator)
    }

    Column {
        id: textCol
        x: Look.rowInset
        width: 190
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs

        KitText {
            width: parent.width
            text: row.label
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        KitText {
            role: "caption"
            width: parent.width
            visible: row.hint !== ""
            text: row.hint
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: holder
        x: 230
        width: parent.width - 250
        height: childrenRect.height
        anchors.verticalCenter: parent.verticalCenter
    }
}
