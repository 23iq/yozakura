import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "Ui.js" as Ui

// Category whose settings do not exist yet.
Item {
    id: page

    required property var category

    PageHeader {
        id: header
        x: (parent.width - width) / 2
        y: 36
        width: Math.min(parent.width - 64, 820)
        category: page.category
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 30
        spacing: 12
        width: Math.min(parent.width - 64, 420)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons[page.category.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 54
            color: Ui.alpha(Colors.primary, 0.6)
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("common.coming_soon")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(4)
            font.weight: Font.Bold
            color: Colors.overBackground
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("prefs.placeholder.desc")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }
}
