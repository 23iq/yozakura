import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.stages
import "ModsModel.js" as ModsModel
import qs.modules.components.kit

// Settings > Mods: the mods master switch and version-check bypass, install
// from a package source, the installed list (search, sort, drag to reorder),
// the selected mod's details and settings, rebuild / restart / rollback of
// the generation. Every action goes through ModsService; installing and
// enabling ask for the trust confirmation first.
FittedFrame {
    id: page
    listForm: true
    hasHint: false

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
        else if (kind === "bypass")
            ModsService.setBypassVersionCheck(true);
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

    // The list form of the page template: a short band (the master switch,
    // how many mods are on, the generation, rebuild / refresh / roll back)
    // over one row of tall cards: the installed mods (search, sort, drag to
    // reorder), the selected mod's details and settings, and adding a mod
    // (package source, the version-check bypass). Each card scrolls inside.
    readonly property real contentHeight: page.height
    readonly property var mods: ModsService.mods ?? []
    readonly property int onCount: page.mods.filter(m => m.enabled).length

    Item {
        id: hero
        objectName: "pageHero"
        x: page.margin
        y: Space.s
        width: page.width - page.margin * 2
        height: page.bandH

        Stage {
            id: band
            objectName: "pageStage"
            anchors.fill: parent
            stageHeight: page.bandH

            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: Look.radius("surface", parent.height)
                offset: Qt.vector2d(0, Space.m)
                blur: Space.xxl
                color: Qt.alpha(Colors.shadow, 0.45)
            }
            Mark {
                anchors.fill: parent
                radius: 0
                color: Qt.alpha(Colors.background, 0.55)
            }

            Row {
                x: Space.xl
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.l

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.puzzlePiece
                    size: Math.round(band.height * 0.36)
                    tone: ModsService.modsEnabled ? "accent" : "muted"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.xs
                    Row {
                        spacing: Space.m
                        KitText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "title"
                            text: I18n.t("mods.band_count", page.onCount, page.mods.length)
                        }
                        Switch {
                            objectName: "modsMasterSwitch"
                            anchors.verticalCenter: parent.verticalCenter
                            checked: ModsService.modsEnabled
                            Accessible.name: I18n.t("mods.toggle_title")
                            onToggled: value => ModsService.setModsEnabled(value)
                        }
                    }
                    KitText {
                        role: "caption"
                        text: (ModsService.busy ? I18n.t("mods.working") + " · " : "") + I18n.t("mods.base") + " " + (ModsService.baseVersion || I18n.t("mods.unknown")) + (ModsService.baseRevision ? " · " + ModsModel.shortRevision(ModsService.baseRevision) : "") + " · " + I18n.t("mods.active") + " " + (ModsService.activeGeneration || "base")
                        font.family: Config.theme.monoFont
                        color: Type.secondary
                        elide: Text.ElideMiddle
                    }
                }
            }

            Column {
                anchors.right: parent.right
                anchors.rightMargin: Space.xl
                anchors.verticalCenter: parent.verticalCenter
                width: Space.px(300)
                spacing: Space.s
                Row {
                    anchors.right: parent.right
                    spacing: Space.s
                    PillButton {
                        visible: ModsService.previousGeneration !== ""
                        kind: "ghost"
                        text: I18n.t("mods.rollback")
                        enabled: !ModsService.busy
                        onClicked: ModsService.rollback()
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
                // a mod built for another base version: ask first, turning
                // the check back on is free (the tooltip says what it does)
                ModsSwitchRow {
                    objectName: "modsBypass"
                    width: parent.width
                    title: I18n.t("mods.bypass_title")
                    checked: ModsService.bypassVersionCheck
                    onToggled: value => value ? page.askConfirm("bypass", null, "") : ModsService.setBypassVersionCheck(false)
                    Tooltip {
                        text: I18n.t("mods.bypass_description")
                        shown: bypassHover.hovered
                    }
                    HoverHandler {
                        id: bypassHover
                    }
                }
            }
        }
    }

    // the row: the list (and adding a mod under it), the selected mod
    Item {
        id: row
        x: page.margin
        y: hero.y + hero.height + page.gap
        width: page.width - page.margin * 2
        height: page.height - y - Space.l

        TallCard {
            id: listCard
            objectName: "settingsSection:mods_list"
            height: row.height
            scrollable: page.confirmKind === ""
            width: Math.round((row.width - page.gap) / 2)

            ModsStatusBanner {
                objectName: "modsBanner"
                width: parent.width
            }
            ModsList {
                objectName: "modsList"
                width: parent.width
                selectedId: page.effectiveId
                onSelectRequested: id => page.selectedId = id
                onToggleRequested: mod => page.toggle(mod)
            }
            Divider {
                width: parent.width
            }
            KitText {
                width: parent.width
                role: "title"
                text: I18n.t("mods.package_source")
            }
            ModsInstallSource {
                width: parent.width
                onInstallRequested: source => page.askConfirm("install", null, source)
            }
        }

        TallCard {
            id: detailsCard
            objectName: "settingsSection:mods_details"
            height: row.height
            scrollable: page.confirmKind === ""
            x: listCard.width + page.gap
            width: row.width - x

            ModsDetails {
                objectName: "modsDetails"
                width: parent.width
                visible: !!page.selectedMod
                mod: page.selectedMod
                onEnableRequested: page.askConfirm("enable", page.selectedMod, page.selectedMod.source ?? "")
            }
            KitText {
                width: parent.width
                visible: !page.selectedMod
                role: "secondary"
                wrapMode: Text.WordWrap
                text: I18n.t("mods.none_selected")
            }
        }
    }

    // A tall card of the row: its content scrolls inside, with a fade
    // at the bottom while more is below.
    component TallCard: Card {
        id: tall
        readonly property bool fixed: true
        default property alias body: inner.data
        // the content scrolls only while no confirmation is open
        property bool scrollable: true

        padding: Look.boxPadding + Space.s

        Item {
            width: tall.contentWidth
            height: tall.height - tall.padding * 2
            Flickable {
                id: scroll
                anchors.fill: parent
                contentWidth: width
                contentHeight: inner.implicitHeight
                clip: true
                interactive: tall.scrollable && contentHeight > height + 1
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: inner
                    width: scroll.width
                    spacing: Space.m
                }
            }
            Mark {
                visible: scroll.interactive && scroll.contentY < scroll.contentHeight - scroll.height - 1
                anchors.bottom: parent.bottom
                width: parent.width
                height: Space.xl
                radius: 0
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Look.cardFill(false)
                    }
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
