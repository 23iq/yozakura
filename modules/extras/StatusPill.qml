import QtQuick
import qs.modules.theme
import qs.config
import "../settings/Ui.js" as Ui

// Small tinted state pill of a catalog card: icon + label in `accent`.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color accent: Colors.primary

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 26
    radius: height / 2
    color: Ui.alpha(root.accent, 0.14)
    border.width: 1
    border.color: Ui.alpha(root.accent, 0.38)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: root.accent
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: root.accent
        }
    }
}
