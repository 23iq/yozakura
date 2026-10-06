import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.extras
import qs.config

// Settings > Apps & Extras: the optional-software catalog (CatalogGrid)
// with its notices (offline, multilib consent, refused installs) and the
// sticky InstallBar. Installs run in the backend queue; the page only
// selects and reports.
Item {
    id: page

    required property var category

    // SettingsShell reveal() hook (search jumps): one page, nothing to scroll to.
    function reveal(section, entry) {
    }

    function reasonsText(reasons) {
        const lines = Object.keys(reasons || {}).map(id => ExtrasService.displayName(id) + " — " + I18n.t("extras.ui.reason." + reasons[id]));
        if (Object.values(reasons || {}).includes("needs_aur_helper"))
            lines.push("", I18n.t("extras.ui.aur_hint"));
        return lines.join("\n");
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 150
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: column
            width: Math.min(page.width - 64, 1040)
            x: (page.width - width) / 2
            y: 36
            spacing: 22

            PageHeader {
                width: parent.width
                category: page.category
            }

            ExtrasNotice {
                objectName: "offlineNotice"
                width: parent.width
                visible: ExtrasService.offline
                tone: "warning"
                icon: "wifiSlash"
                title: I18n.t("extras.ui.offline.title")
                message: I18n.t("extras.ui.offline.message")
                PillButton {
                    text: I18n.t("extras.ui.offline.check")
                    icon: "arrowsClockwise"
                    onClicked: ExtrasService.refresh()
                }
            }

            MultilibConfirm {
                objectName: "multilibConfirm"
                width: parent.width
                visible: !!ExtrasService.confirm && ExtrasService.confirm.kind === "multilib"
                request: ExtrasService.confirm
                onAccepted: ExtrasService.acceptConfirm()
                onDeclined: ExtrasService.dismissConfirm()
            }

            ExtrasNotice {
                objectName: "unavailableNotice"
                width: parent.width
                visible: !!ExtrasService.unavailable
                tone: "error"
                icon: "warning"
                title: I18n.t("extras.ui.refused.title")
                message: ExtrasService.unavailable ? page.reasonsText(ExtrasService.unavailable.reasons) : ""
                PillButton {
                    kind: "ghost"
                    text: I18n.t("extras.ui.dismiss")
                    onClicked: ExtrasService.dismissUnavailable()
                }
            }

            ExtrasNotice {
                objectName: "errorNotice"
                width: parent.width
                visible: ExtrasService.error !== ""
                tone: "error"
                icon: "warning"
                title: I18n.t("extras.ui.error.title")
                message: ExtrasService.error
                PillButton {
                    kind: "ghost"
                    text: I18n.t("extras.ui.dismiss")
                    onClicked: ExtrasService.error = ""
                }
            }

            CatalogGrid {
                id: grid
                objectName: "catalogGrid"
                width: parent.width
                mode: "settings"
                onLogRequested: (job, name) => logPopup.show(job, name)
            }
        }
    }

    InstallBar {
        id: bar
        objectName: "installBar"
        width: Math.min(page.width - 48, 860)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        selected: grid.selected
        onClearRequested: grid.selected = {}
    }

    LogPopup {
        id: logPopup
        objectName: "logPopup"
    }
}
