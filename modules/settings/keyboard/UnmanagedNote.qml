import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.config

// Shown while Yozakura does not manage the keyboard (keyboard.managed):
// "Using your compositor's keyboard settings", the first change takes them
// over. When the compositor cannot report them (KeyboardService.unreadable)
// a change would replace them, so it says so and asks for an explicit
// takeover first.
Column {
    id: root

    readonly property bool unreadable: KeyboardService.unreadable

    spacing: 10

    Row {
        width: parent.width
        spacing: 10

        Text {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            text: root.unreadable ? Icons.warning : Icons.info
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(1)
            color: root.unreadable ? Colors.error : Colors.primary
        }

        Text {
            objectName: "unmanagedText"
            width: root.width - icon.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t(root.unreadable ? "prefs.keyboard.unreadable" : "prefs.keyboard.unmanaged")
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }

    PillButton {
        objectName: "takeOverButton"
        visible: root.unreadable
        kind: "filled"
        icon: "check"
        text: I18n.t("prefs.keyboard.take_over")
        onClicked: KeyboardService.takeOver()
    }
}
