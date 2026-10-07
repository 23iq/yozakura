import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Shown while a preset bundle is dragged over the studio: the page takes
// the kit's active look (accent tint + hairline: a drop target is an active
// state) over a scrim, under a floating Surface with the import glyph and the message.
Item {
    id: root

    // The page recedes under a scrim so the drop target reads clearly.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.78)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Space.m
        radius: Space.surfaceRadius
        color: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, Look.activeTint / 2)
        border.width: Space.hairline
        border.color: Type.accent
    }

    Surface {
        anchors.centerIn: parent
        floating: true
        padding: Space.xl

        Column {
            spacing: Space.m

            IconButton {
                anchors.horizontalCenter: parent.horizontalCenter
                size: "l"
                active: true
                icon: Icons.downloadSimple
                enabled: false
                opacity: 1
            }
            KitText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "title"
                text: I18n.t("prefs.presets.drop")
            }
        }
    }
}
