import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// A titled card of the Keyboard page: tinted icon, title, subtitle, then the
// rows (children). Same look as the monitor details card of Displays.
Group {
    id: root

    property string icon: "keyboard"
    property string title: ""
    property string subtitle: ""
    // Extra controls on the right of the header
    default property alias rows: body.data
    property alias headerActions: actions.data

    Column {
        id: column
        width: parent.width

        Item {
            width: parent.width
            height: Space.controlL + Space.m

            // Neutral icon tile: the accent stays for active state
            StyledRect {
                id: badge
                x: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                width: Space.controlM
                height: Space.controlM
                variant: "common"
                enableShadow: false
                radius: Look.radius("control", height)
                Icon {
                    role: "title"
                    tone: "secondary"
                    anchors.centerIn: parent
                    icon: Icons[root.icon] ?? ""
                }
            }
            Column {
                anchors.left: badge.right
                anchors.leftMargin: Space.l
                anchors.right: actions.left
                anchors.rightMargin: Space.l
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs / 2
                KitText {
                    role: "title"
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                }
                KitText {
                    role: "secondary"
                    width: parent.width
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    elide: Text.ElideRight
                }
            }
            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
            }
        }

        Column {
            id: body
            width: parent.width
        }
    }
}
