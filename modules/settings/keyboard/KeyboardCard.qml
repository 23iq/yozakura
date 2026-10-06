import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui

// A titled card of the Keyboard page: tinted icon, title, subtitle, then the
// rows (children). Same look as the monitor details card of Displays.
StyledRect {
    id: root

    property string icon: "keyboard"
    property string title: ""
    property string subtitle: ""
    // Extra controls on the right of the header
    default property alias rows: body.data
    property alias headerActions: actions.data

    variant: "pane"
    radius: Styling.radius(4)
    enableShadow: false
    implicitHeight: column.implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.55)
        z: 10
    }

    Column {
        id: column
        width: parent.width

        Item {
            width: parent.width
            height: 76

            Rectangle {
                id: badge
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: Math.min(Styling.radius(2), 14)
                color: Ui.alpha(Colors.primary, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: Icons[root.icon] ?? ""
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(4)
                    color: Colors.primary
                }
            }
            Column {
                anchors.left: badge.right
                anchors.leftMargin: 14
                anchors.right: actions.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(2)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    width: parent.width
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                }
            }
            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
            }
        }

        Column {
            id: body
            width: parent.width
        }
    }
}
