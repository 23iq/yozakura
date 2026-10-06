import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config

// "Using your compositor's keyboard settings": shown while Yozakura does not
// manage the keyboard (keyboard.managed); the first change takes them over.
Row {
    id: root

    spacing: 10

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.info
        font.family: Icons.font
        font.pixelSize: Styling.fontSize(1)
        color: Colors.primary
    }

    Text {
        objectName: "unmanagedText"
        width: root.width - icon.width - root.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.t("prefs.keyboard.unmanaged")
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
    }
}
