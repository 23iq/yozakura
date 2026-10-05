import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../settings/Ui.js" as Ui

// Header of a regular step (icon chip, title, subtitle) above the step's
// content. Hero steps (welcome, finish) skip the header.
Item {
    id: root

    property var step: ({})
    property bool hero: step.hero === true
    default property alias content: body.data

    Row {
        id: header
        visible: !root.hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Math.round(Styling.fontSize(0) * 0.9)

        Rectangle {
            id: chip
            width: Math.round(Styling.fontSize(0) * 3)
            height: width
            radius: Math.min(width / 2, Styling.radius(2))
            color: Ui.alpha(Colors.primary, 0.16)
            Text {
                anchors.centerIn: parent
                text: Icons[root.step.icon || ""] ?? ""
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(4)
                color: Colors.primary
            }
        }

        Column {
            width: header.width - chip.width - header.spacing
            spacing: 4
            anchors.verticalCenter: chip.verticalCenter
            Text {
                width: parent.width
                text: root.step.title ? I18n.t(root.step.title) : ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(9)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                width: parent.width
                text: root.step.subtitle ? I18n.t(root.step.subtitle) : ""
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }
        }
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.hero ? parent.top : header.bottom
        anchors.topMargin: root.hero ? 0 : Math.round(Styling.fontSize(0) * 1.8)
        anchors.bottom: parent.bottom
    }
}
