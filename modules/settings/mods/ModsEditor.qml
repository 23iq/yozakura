import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel
import "../Ui.js" as Ui

// Settings > Mods: the mods master switch and version-check bypass, install
// from a package source, the installed list (search, sort, drag to reorder),
// the selected mod's details and settings, rebuild / restart / rollback of
// the generation. Every action goes through ModsService; installing and
// enabling ask for the trust confirmation first.
Item {
    id: page

    required property var category

    property string selectedId: ""

    // Pending trust confirmation ("" = none).
    property string confirmKind: ""
    property var confirmMod: null
    property string confirmSource: ""

    readonly property var selectedMod: ModsModel.selectMod(ModsService.mods, page.selectedId)
    // Derived from selectedMod instead of written back into selectedId: that
    // write-back made the selection bind to itself in a loop.
    readonly property string effectiveId: page.selectedMod?.id ?? ""

    // SettingsShell reveal() hook (search jumps): one page, nothing to scroll to.
    function reveal(section, entry) {
    }

    function askConfirm(kind, mod, source) {
        page.confirmKind = kind;
        page.confirmMod = mod ?? null;
        page.confirmSource = source ?? "";
    }

    function closeConfirm() {
        page.confirmKind = "";
        page.confirmMod = null;
        page.confirmSource = "";
    }

    function runConfirmed() {
        const kind = page.confirmKind;
        const mod = page.confirmMod;
        const source = page.confirmSource;
        page.closeConfirm();
        if (kind === "install")
            ModsService.install(source);
        else if (kind === "enable" && mod)
            ModsService.setEnabled(mod.id, true);
    }

    function toggle(mod) {
        if (mod.enabled)
            ModsService.setEnabled(mod.id, false);
        else
            page.askConfirm("enable", mod, mod.source ?? "");
    }

    onEffectiveIdChanged: ModsService.loadSettings(page.effectiveId)
    Component.onCompleted: ModsService.refresh()
    // The daemon clears the restart flag once a new generation survives its
    // health window; re-reading on show keeps the banner from outliving it.
    onVisibleChanged: {
        if (visible)
            ModsService.refresh();
    }

    // The page can already be open when that happens: re-read only while
    // the restart banner is on screen.
    Timer {
        interval: 5000
        repeat: true
        running: page.visible && ModsService.restartRequired && !ModsService.busy
        onTriggered: ModsService.refresh()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 120
        clip: true
        interactive: page.confirmKind === ""
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: column
            width: Math.min(flick.width - 64, 820)
            x: (flick.width - width) / 2
            y: 36
            spacing: 30

            PageHeader {
                width: parent.width
                category: page.category
            }

            Column {
                width: parent.width
                spacing: Metrics.spacing + 4

                RowLayout {
                    width: parent.width
                    spacing: Metrics.spacing

                    Text {
                        Layout.fillWidth: true
                        text: ModsService.busy ? I18n.t("mods.working") : ""
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        elide: Text.ElideRight
                    }

                    PillButton {
                        kind: "ghost"
                        icon: "arrowCounterClockwise"
                        text: I18n.t("mods.refresh")
                        enabled: !ModsService.busy
                        onClicked: ModsService.refresh()
                    }

                    PillButton {
                        icon: "arrowsClockwise"
                        text: I18n.t("mods.rebuild")
                        enabled: !ModsService.busy
                        onClicked: ModsService.rebuild()
                    }
                }

                ModsStatusBanner {
                    objectName: "modsBanner"
                    width: parent.width
                }
            }

            ModsCard {
                width: parent.width

                ModsSwitchRow {
                    title: I18n.t("mods.toggle_title")
                    description: I18n.t("mods.toggle_description")
                    checked: ModsService.modsEnabled
                    onToggled: value => ModsService.setModsEnabled(value)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Ui.alpha(Colors.outlineVariant, 0.45)
                }

                ModsSwitchRow {
                    title: I18n.t("mods.bypass_title")
                    description: I18n.t("mods.bypass_description")
                    checked: ModsService.bypassVersionCheck
                    onToggled: value => ModsService.setBypassVersionCheck(value)
                }
            }

            ModsCard {
                width: parent.width
                title: I18n.t("mods.package_source")

                ModsInstallSource {
                    onInstallRequested: source => page.askConfirm("install", null, source)
                }
            }

            ModsList {
                objectName: "modsList"
                width: parent.width
                selectedId: page.effectiveId
                onSelectRequested: id => page.selectedId = id
                onToggleRequested: mod => page.toggle(mod)
            }

            ModsDetails {
                objectName: "modsDetails"
                width: parent.width
                visible: !!page.selectedMod
                mod: page.selectedMod
                onEnableRequested: page.askConfirm("enable", page.selectedMod, page.selectedMod.source ?? "")
            }

            RowLayout {
                width: parent.width
                spacing: Metrics.spacing

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("mods.base") + " " + (ModsService.baseVersion || I18n.t("mods.unknown")) + (ModsService.baseRevision ? " · " + ModsModel.shortRevision(ModsService.baseRevision) : "") + " · " + I18n.t("mods.active") + " " + (ModsService.activeGeneration || "base")
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideMiddle
                }

                PillButton {
                    visible: ModsService.previousGeneration !== ""
                    kind: "ghost"
                    text: I18n.t("mods.rollback")
                    enabled: !ModsService.busy
                    onClicked: ModsService.rollback()
                }
            }
        }
    }

    ModsConfirmDialog {
        anchors.fill: parent
        kind: page.confirmKind
        mod: page.confirmMod
        source: page.confirmSource
        onConfirmed: page.runConfirmed()
        onCancelled: page.closeConfirm()
    }
}
