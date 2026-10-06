import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config

// Inline consent card shown when an install needs Arch's 32-bit [multilib]
// repository (Steam): enabling it edits /etc/pacman.conf behind the
// password prompt, so it is never done silently.
ExtrasNotice {
    id: root

    // ExtrasService.confirm: {kind: "multilib", entries: [...], ids: [...]}
    property var request: null
    signal accepted
    signal declined

    readonly property string names: (root.request && root.request.entries ? root.request.entries : []).map(id => ExtrasService.displayName(id)).join(", ")

    tone: "warning"
    icon: "packageBox"
    title: I18n.t("extras.ui.multilib.title", root.names)
    message: I18n.t("extras.ui.multilib.message")

    ExtrasButton {
        objectName: "confirmDecline"
        kind: "ghost"
        text: I18n.t("extras.ui.multilib.decline")
        onClicked: root.declined()
    }
    ExtrasButton {
        objectName: "confirmAccept"
        kind: "filled"
        icon: "check"
        text: I18n.t("extras.ui.multilib.accept")
        onClicked: root.accepted()
    }
}
