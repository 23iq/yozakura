pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.keybinds

// One BindModel group of the cheatsheet as a kit Group: its label and the
// bind rows (the language gives it hairlines, a glass card or a tile).
Group {
    id: root

    // {group: BindModel.GROUPS entry, rows}
    required property var model
    property string selectedUid: ""
    signal editRequested(string uid)

    label: I18n.t(root.model.group.title)

    Column {
        id: rows
        width: parent.width
        spacing: 0

        Repeater {
            model: root.model.rows
            delegate: CheatsheetRow {
                required property var modelData
                width: rows.width
                bind: modelData
                highlighted: modelData.uid === root.selectedUid
                onEditRequested: uid => root.editRequested(uid)
            }
        }
    }
}
