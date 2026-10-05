import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// Placeholder for a planned setting: shows the row with a badge.
Item {
    id: root

    property var entry

    implicitHeight: 26

    Rectangle {
        width: label.implicitWidth + 24
        height: 26
        radius: 13
        color: Ui.alpha(Colors.tertiary, 0.14)
        border.width: 1
        border.color: Ui.alpha(Colors.tertiary, 0.35)
        Row {
            id: label
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.sparkle
                font.family: Icons.font
                font.pixelSize: 12
                color: Colors.tertiary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("common.coming_soon")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.DemiBold
                color: Colors.tertiary
            }
        }
    }
}
