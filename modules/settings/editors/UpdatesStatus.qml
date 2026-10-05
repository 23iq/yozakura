import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.modules.settings

// Installed version, the newest release seen by the update checker, when it
// last looked, and actions: check now, changelog.
Item {
    id: root

    property var entry
    readonly property string current: UpdateService.currentVersion ?? ""
    readonly property string latest: UpdateService.lastDetectedVersion ?? ""
    readonly property bool newer: latest !== "" && typeof UpdateService.isNewer === "function" && UpdateService.isNewer(latest, current)
    readonly property real lastCheck: UpdateService.lastCheckTime ?? 0

    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: parent.width
        spacing: 10

        StatusLine {
            width: parent.width
            icon: root.newer ? "downloadSimple" : "checkCircle"
            tone: root.newer ? "warn" : "ok"
            title: root.newer ? I18n.t("prefs.updates.available", root.latest) : I18n.t("prefs.updates.current", root.current)
            detail: UpdateService.checking ? I18n.t("prefs.updates.checking") : (root.lastCheck > 0 ? I18n.t("prefs.updates.last_check", Qt.formatDateTime(new Date(root.lastCheck), "d MMM, HH:mm")) : I18n.t("prefs.updates.never_checked"))

            PillButton {
                kind: "ghost"
                icon: "arrowsClockwise"
                text: I18n.t("prefs.updates.check_now")
                enabled: !UpdateService.checking
                onClicked: UpdateService.checkUpdates()
            }
        }

        Row {
            spacing: 8

            PillButton {
                kind: "ghost"
                icon: "fileText"
                text: I18n.t("prefs.updates.changelog")
                onClicked: Quickshell.execDetached(["xdg-open", UpdateService.changelogUrl ?? Brand.repoUrl])
            }
        }
    }
}
