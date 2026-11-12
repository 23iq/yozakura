import QtQuick
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services

// The Settings window while a separate Settings process (ProcessRole)
// builds its content asynchronously: the window background with a quiet
// caption, so the frame shows at once instead of an empty surface.
StyledRect {
    variant: "bg"
    radius: 0
    enableBorder: false

    KitText {
        objectName: "settingsLoading"
        anchors.centerIn: parent
        role: "caption"
        color: Type.muted
        text: I18n.t("prefs.window.loading")
    }
}
