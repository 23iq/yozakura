pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// A titled glass card of cheatsheet rows (one BindModel group).
StyledRect {
    id: root

    // {group: BindModel.GROUPS entry, rows}
    required property var model
    property string selectedUid: ""
    signal editRequested(string uid)

    variant: "pane"
    radius: Styling.radius(2)
    implicitHeight: body.implicitHeight + 24

    Column {
        id: body
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 2

        Row {
            spacing: 8
            bottomPadding: 6
            leftPadding: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons[root.model.group.icon] ?? ""
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(1)
                color: Colors.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t(root.model.group.title)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.model.rows.length
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.outline
            }
        }

        Repeater {
            model: root.model.rows
            delegate: CheatsheetRow {
                required property var modelData
                width: body.width
                bind: modelData
                selected: modelData.uid === root.selectedUid
                onEditRequested: uid => root.editRequested(uid)
            }
        }
    }
}
