import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.config
import qs.modules.components.kit

// Shown while Yozakura does not manage the keyboard (keyboard.managed):
// "Using your compositor's keyboard settings", the first change takes them
// over. When the compositor cannot report them (KeyboardService.unreadable)
// a change would replace them, so it says so and asks for an explicit
// takeover first.
Column {
    id: root

    readonly property bool unreadable: KeyboardService.unreadable

    spacing: Space.m

    Row {
        width: parent.width
        spacing: Space.m

        Icon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            icon: root.unreadable ? Icons.warning : Icons.info
            color: root.unreadable ? Colors.error : Colors.primary
        }

        KitText {
            objectName: "unmanagedText"
            role: "secondary"
            width: root.width - icon.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t(root.unreadable ? "prefs.keyboard.unreadable" : "prefs.keyboard.unmanaged")
            wrapMode: Text.WordWrap
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
