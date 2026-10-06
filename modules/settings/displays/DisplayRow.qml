import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// One labelled row of the monitor details card: title + hint on the left,
// the control(s) on the right. Children land in the right column.
Item {
    id: row

    property string label: ""
    property string hint: ""
    property bool separator: true
    default property alias content: holder.data

    implicitHeight: Math.max(textCol.implicitHeight, holder.childrenRect.height) + 28

    Rectangle {
        x: 20
        width: parent.width - 40
        height: 1
        visible: row.separator
        color: Ui.alpha(Colors.outlineVariant, 0.45)
    }

    Column {
        id: textCol
        x: 20
        width: 190
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: row.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: Colors.overBackground
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: row.hint !== ""
            text: row.hint
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
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
