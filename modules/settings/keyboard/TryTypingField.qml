import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui
import "../../services/KeyboardModel.js" as KeyboardModel

// Scratch field to feel the key repeat and the layout switch. Shows the
// layout in use as a badge on the right.
StyledRect {
    id: root

    property alias text: input.text

    variant: "internalbg"
    radius: Styling.radius(3)
    enableShadow: false
    implicitHeight: 54

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.6)
        z: 10
    }

    TextInput {
        id: input
        objectName: "tryInput"
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: badge.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        selectByMouse: true
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(1)
        color: Colors.overBackground
        selectionColor: Colors.primary
        selectedTextColor: Colors.overPrimary

        Text {
            visible: input.text === "" && !input.activeFocus
            text: I18n.t("prefs.keyboard.try.placeholder")
            font: input.font
            color: Ui.alpha(Colors.overSurfaceVariant, 0.7)
        }
    }

    Rectangle {
        id: badge
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(34, code.implicitWidth + 16)
        height: 28
        radius: 8
        color: Ui.alpha(Colors.primary, 0.2)
        Text {
            id: code
            objectName: "tryBadge"
            anchors.centerIn: parent
            text: KeyboardService.shortLabel
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Bold
            color: Colors.primary
        }
    }
}
