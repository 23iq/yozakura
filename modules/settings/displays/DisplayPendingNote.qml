import QtQuick
import qs.modules.services
import qs.modules.settings

// Compositors that cannot preview a layout (MangoWC) apply it only once it
// is kept: no countdown, just the choice.
DisplayNotice {
    id: root

    tone: "info"
    icon: "monitor"
    title: I18n.t("prefs.displays.deferred.title")
    message: I18n.t("prefs.displays.deferred.desc")

    PillButton {
        objectName: "deferredRevert"
        kind: "ghost"
        text: I18n.t("prefs.displays.revert")
        onClicked: DisplaysService.revert()
    }
    PillButton {
        objectName: "deferredKeep"
        kind: "filled"
        icon: "accept"
        text: I18n.t("prefs.displays.keep")
        onClicked: DisplaysService.keep()
    }
}
