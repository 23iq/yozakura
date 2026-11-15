import QtQuick
import qs.modules.components.kit

// The fixed trailing slot of the converter's rows: room for three small
// buttons (show, copy, remove / stop), filled from the right. Rows and kind
// headers end with one, so the target chips before it form one column
// whatever each row can do now.
Item {
    id: root

    default property alias content: buttons.data
    readonly property int cells: 3

    implicitWidth: Space.controlS * root.cells + Space.s * (root.cells - 1)
    implicitHeight: Space.controlS

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.s
    }
}
