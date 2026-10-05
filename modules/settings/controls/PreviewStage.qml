import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// Inset area that hosts a live preview, tagged "Live preview".
Item {
    id: stage

    property real stageHeight: 120
    property bool showTag: true
    default property alias content: area.data

    implicitHeight: stageHeight

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(2), 18)
        color: Ui.alpha(Colors.surfaceContainerLowest, 0.75)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Item {
        id: area
        anchors.fill: parent
        anchors.margins: 1
        clip: true
    }

    Rectangle {
        visible: stage.showTag
        x: 10
        y: 8
        width: tag.implicitWidth + 16
        height: 18
        radius: 9
        color: Ui.alpha(Colors.surfaceContainerLowest, 0.72)

        Row {
            id: tag
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Colors.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("prefs.common.live_preview").toUpperCase()
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-5)
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                color: Ui.alpha(Colors.overSurfaceVariant, 0.9)
            }
        }
    }
}
