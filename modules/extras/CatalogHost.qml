pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import "ExtrasModel.js" as ExtrasModel

// Everything a catalog screen needs, reusable by Settings > Apps & Extras
// and the onboarding app steps: an optional `header`, the CatalogGrid in
// its own Flickable, the log popup, and a sticky bottom stack (offline /
// multilib consent / refused install / error notices above the InstallBar)
// that stays in view however far the grid is scrolled.
//
// `autoPreselect` (onboarding) pre-checks the recommended entries that are
// still missing, once, when catalog and status first arrive.
Item {
    id: root

    // "settings" | "onboarding"
    property string mode: "settings"
    // Category ids to offer ([] = all)
    property var categories: []
    property bool autoPreselect: root.mode === "onboarding"
    // false: the inner Flickable does not scroll; the parent must size the
    // host to its implicitHeight and scroll it, and the bottom stack then
    // sits at the host's bottom, under the grid (not sticky).
    property bool scrollable: true
    // Shown above the grid (Settings: the page header)
    property Component header: null
    // Shown below the grid
    property Component footer: null
    property alias showChips: grid.showChips
    property alias minCardWidth: grid.minCardWidth
    property alias sections: grid.sections
    property real maxContentWidth: 1040
    property real sideMargin: 32
    property real topMargin: 36
    property alias selected: grid.selected
    readonly property alias grid: grid
    property bool _preselected: false

    implicitHeight: column.implicitHeight + root.topMargin + stack.height + 44

    function reasonsText(reasons) {
        const lines = Object.keys(reasons || {}).map(id => ExtrasService.displayName(id) + " — " + I18n.t("extras.ui.reason." + reasons[id]));
        if (Object.values(reasons || {}).includes("needs_aur_helper"))
            lines.push("", I18n.t("extras.ui.aur_hint"));
        return lines.join("\n");
    }

    function _maybePreselect() {
        if (!root.autoPreselect || root._preselected || !ExtrasService.catalog || Object.keys(ExtrasService.status).length === 0)
            return;
        root._preselected = true;
        const pre = ExtrasModel.preselect(ExtrasService.catalog, ExtrasService.status, "onboarding");
        // only what this host offers: hidden picks would install unseen
        if (root.categories.length > 0)
            for (const id in pre) {
                if (!root.categories.includes(ExtrasService.entry(id)?.category))
                    delete pre[id];
            }
        grid.selected = pre;
    }

    Component.onCompleted: root._maybePreselect()

    Connections {
        target: ExtrasService
        function onCatalogChanged() {
            root._maybePreselect();
        }
        function onStatusChanged() {
            root._maybePreselect();
        }
    }

    Flickable {
        id: flick
        objectName: "catalogFlick"
        anchors.fill: parent
        interactive: root.scrollable
        contentWidth: width
        contentHeight: root.implicitHeight
        clip: root.scrollable
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
            policy: root.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Column {
            id: column
            width: Math.min(root.width - 2 * root.sideMargin, root.maxContentWidth)
            x: (root.width - width) / 2
            y: root.topMargin
            spacing: 22

            Loader {
                width: parent.width
                active: root.header !== null
                visible: active
                sourceComponent: root.header
            }

            CatalogGrid {
                id: grid
                objectName: "catalogGrid"
                width: parent.width
                mode: root.mode
                categories: root.categories
                onLogRequested: (job, name) => logPopup.show(job, name)
            }

            Loader {
                width: parent.width
                active: root.footer !== null
                visible: active
                sourceComponent: root.footer
            }
        }
    }

    // Sticky bottom stack: notices above the install bar.
    Column {
        id: stack
        width: Math.min(column.width, 860)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        spacing: 10

        ExtrasNotice {
            objectName: "offlineNotice"
            width: parent.width
            visible: ExtrasService.offline
            tone: "warning"
            icon: "wifiSlash"
            title: I18n.t("extras.ui.offline.title")
            message: I18n.t("extras.ui.offline.message")
            ExtrasButton {
                enabled: !ExtrasService.checking
                text: ExtrasService.checking ? I18n.t("extras.ui.offline.checking") : I18n.t("extras.ui.offline.check")
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
            message: ExtrasService.unavailable ? root.reasonsText(ExtrasService.unavailable.reasons) : ""
            ExtrasButton {
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
            ExtrasButton {
                kind: "ghost"
                text: I18n.t("extras.ui.dismiss")
                onClicked: ExtrasService.error = ""
            }
        }

        InstallBar {
            objectName: "installBar"
            width: parent.width
            selected: grid.selected
            onClearRequested: grid.selected = {}
        }
    }

    LogPopup {
        id: logPopup
        objectName: "logPopup"
    }
}
