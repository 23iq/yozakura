import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Header of a regular step (icon tile, title, subtitle) above the step's
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
        spacing: Space.l

        Art {
            id: chip
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons[root.step.icon || ""] ?? ""
        }

        Column {
            width: header.width - chip.width - header.spacing
            spacing: Space.xs
            anchors.verticalCenter: chip.verticalCenter
            KitText {
                width: parent.width
                role: "title"
                text: root.step.title ? I18n.t(root.step.title) : ""
                elide: Text.ElideRight
            }
            KitText {
                width: parent.width
                role: "secondary"
                text: root.step.subtitle ? I18n.t(root.step.subtitle) : ""
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.hero ? parent.top : header.bottom
        anchors.topMargin: root.hero ? 0 : Space.xl
        anchors.bottom: parent.bottom
    }
}
