import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Category whose settings do not exist yet.
Item {
    id: page

    required property var category

    PageHeader {
        id: header
        x: (parent.width - width) / 2
        y: Space.xxl
        width: Math.min(parent.width - Space.xxl * 2, 820)
        category: page.category
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Space.xl
        spacing: Space.m
        width: Math.min(parent.width - Space.xxl * 2, 420)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons[page.category.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Type.size("display")
            color: Type.muted
        }
        KitText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "title"
            text: I18n.t("common.coming_soon")
        }
        KitText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            role: "secondary"
            text: I18n.t("prefs.placeholder.desc")
        }
    }
}
