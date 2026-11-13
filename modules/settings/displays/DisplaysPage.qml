pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.editors
import "../../services/DisplayModel.js" as DisplayModel
import "DisplayFormat.js" as DisplayFormat
import "../../../config/JsonUtil.js" as JsonUtil
import qs.modules.components.kit

// Settings > Displays, fitted like a converted page (modules/settings/
// AGENTS.md, PAGE COMPOSITION): the hero is your monitors as they are
// arranged (drag one to move it, click one to pick it), the picked monitor
// beside it (on / off, rotation, adaptive sync, Identify, Apply), one hint
// line, then one row of cards for the picked monitor: resolution, refresh
// rate, scale ("Aa" that grows) and night light. Edits build a draft;
// Apply runs it for 15 s on every screen with a "keep these settings?"
// prompt (DisplayConfirmOverlay); keeping it saves it. Night light is live.
FittedFrame {
    id: page
    stackable: true
    stackedHeight: row.y + row.height + page.pad

    required property var category

    // The layout being edited: one config per connected output
    property var draft: []
    property string selectedName: ""

    // First pair of overlapping enabled monitors ([] when clean): Apply is blocked
    readonly property var overlap: DisplayModel.firstOverlap(draft)
    readonly property var notice: DisplaysService.notice

    readonly property var live: DisplaysService.currentConfigs()
    readonly property bool dirty: !JsonUtil.deepEqual(draft, live)
    readonly property var selectedConfig: draft.find(c => c.name === selectedName) ?? null
    readonly property int selectedIndex: draft.findIndex(c => c.name === selectedName)
    readonly property var selectedOutput: page.selectedConfig ? DisplayFormat.outputFor(DisplaysService.outputs, page.selectedName) : null
    readonly property bool active: !!page.selectedConfig && page.selectedConfig.enabled !== false
    readonly property bool busy: DisplaysService.pending || DisplaysService.applying || page.overlap.length > 0

    // SettingsShell calls reveal() on search jumps for every page type; this
    // page has no entries to scroll to.
    function reveal(section, entry) {
    }

    function resync() {
        draft = DisplaysService.currentConfigs();
        if (!draft.some(c => c.name === selectedName))
            selectedName = draft.length > 0 ? draft[0].name : "";
    }

    function enabledCount(list) {
        return list.filter(c => c.enabled !== false).length;
    }

    // Applies `values` to one monitor of the draft, then re-arranges so size,
    // rotation or enabling it never leaves tiles overlapping.
    function edit(name, values) {
        const cur = draft.find(c => c.name === name);
        if (!cur)
            return;
        if (values.enabled === false && enabledCount(draft) <= 1 && cur.enabled !== false)
            return;
        const next = Object.assign({}, cur, values);
        if (values.enabled === true && cur.enabled === false) {
            next.x = draft.reduce((m, c) => c.enabled === false ? m : Math.max(m, c.x + DisplayModel.logicalSize(c).w), 0);
            next.y = 0;
        }
        const list = draft.map(c => c.name === name ? next : c);
        draft = values.enabled === false ? list : DisplayModel.arrange(list, name, next.x, next.y);
    }

    function pickResolution(name, width, height) {
        const out = DisplayFormat.outputFor(DisplaysService.outputs, name);
        const mode = Object.assign({}, out, {
            "width": width,
            "height": height
        });
        edit(name, {
            "width": width,
            "height": height,
            "refresh": out ? DisplayModel.bestRefresh(mode) : 0
        });
    }

    function applyDraft() {
        if (overlap.length > 0)
            return;
        DisplaysService.apply(draft);
    }

    Component.onCompleted: {
        DisplaysService.refresh();
        DisplaysService.scanConflicts();
        resync();
    }

    Connections {
        target: DisplaysService
        function onOutputsChanged() {
            const names = DisplaysService.outputs.map(o => o.name).join();
            if (!page.dirty || names !== page.draft.map(c => c.name).join())
                page.resync();
        }
    }

    // ---- the hero: the arrangement and the picked monitor beside it --------
    Item {
        id: hero
        // the page's hero (tests/settings-fit.test.py)
        readonly property bool fittedHero: true
        x: page.margin
        y: Space.s
        width: page.width - page.margin * 2
        height: page.heroH

        readonly property real stageW: Math.min(hero.width - page.sideW - page.gap, hero.height * 16 / 9)
        readonly property real groupX: (hero.width - hero.stageW - page.sideW - page.gap) / 2

        RectangularShadow {
            anchors.fill: arrangement
            radius: Look.radius("surface", arrangement.height)
            offset: Qt.vector2d(0, Space.l)
            blur: Space.xxl * 2
            color: Qt.alpha(Colors.shadow, 0.55)
        }
        DisplayArrangement {
            id: arrangement
            objectName: "arrangement"
            x: hero.groupX
            width: hero.stageW
            height: hero.height
            configs: page.draft
            outputs: DisplaysService.outputs
            selectedName: page.selectedName
            onPicked: name => page.selectedName = name
            onMoved: (name, x, y) => page.draft = DisplayModel.arrange(page.draft, name, x, y)
        }

        // what needs saying sits over the arrangement's foot
        Column {
            x: arrangement.x + Space.l
            width: arrangement.width - Space.l * 2
            anchors.bottom: arrangement.bottom
            anchors.bottomMargin: Space.l
            spacing: Space.s

            DisplayNotice {
                objectName: "applyError"
                width: parent.width
                visible: page.notice.message !== "" && page.notice.kind !== "info"
                tone: "error"
                icon: "warning"
                title: I18n.t("prefs.displays." + ({
                        "keep": "keep_failed",
                        "revert": "revert_failed",
                        "restore": "restore_failed"
                    })[page.notice.kind] ?? "apply_failed")
                message: page.notice.message
            }
            DisplayNotice {
                objectName: "unchangedNote"
                width: parent.width
                visible: page.notice.kind === "info"
                tone: "info"
                icon: "info"
                title: I18n.t("prefs.displays.unchanged")
            }
            DisplayNotice {
                objectName: "overlapNote"
                width: parent.width
                visible: page.overlap.length > 0
                tone: "warning"
                icon: "warning"
                title: I18n.t("prefs.displays.overlap")
                message: page.overlap.join(" / ")
            }
            DisplayPendingNote {
                objectName: "deferredNote"
                width: parent.width
                visible: DisplaysService.pending && !DisplaysService.session.live
            }
            DisplayConflictBanner {
                objectName: "conflictBanner"
                width: parent.width
                visible: DisplaysService.conflicts.length > 0
                count: DisplaysService.conflicts.length
                skipped: DisplaysService.moveSkipped
                onMoveRequested: DisplaysService.moveConflicts()
            }
        }

        DisplayMonitorSide {
            id: side
            objectName: "monitorSide"
            x: arrangement.x + arrangement.width + page.gap
            y: Space.l
            width: page.sideW
            config: page.selectedConfig
            output: page.selectedOutput
            dirty: page.dirty
            busy: page.busy
            onPatch: values => page.edit(page.selectedName, values)
            onIdentify: DisplaysService.identify()
            onDiscard: page.resync()
            onApply: page.applyDraft()
        }
    }

    KitText {
        id: hint
        objectName: "heroHint"
        x: page.margin
        y: hero.y + hero.height + Space.s
        width: page.width - page.margin * 2
        horizontalAlignment: Text.AlignHCenter
        role: "secondary"
        text: I18n.t("prefs.displays.hero_hint")
    }

    // ---- the row: the picked monitor's mode, scale and the night light ------
    Flow {
        id: row
        objectName: "displaysRow"
        x: page.margin
        // stacked (narrow window): under the hint, one card a line
        y: page.stacked ? hint.y + hint.height + page.gap : page.height - page.rowH - page.pad
        width: page.width - page.margin * 2
        spacing: page.gap
        readonly property real cardW: page.stacked ? row.width : (row.width - row.spacing * 3) / 4

        PageCard {
            objectName: "displayCard:resolution"
            width: row.cardW
            height: page.rowH
            title: I18n.t("prefs.displays.resolution")
            value: page.selectedConfig ? DisplayFormat.formatResolution(page.selectedConfig.width, page.selectedConfig.height) : ""
            DisplayResolutionList {
                objectName: "resolutionSelector"
                anchors.fill: parent
                enabled: page.active
                options: page.selectedOutput ? DisplayFormat.resolutionOptions(page.selectedOutput) : []
                value: page.selectedConfig ? DisplayFormat.resolutionKey(page.selectedConfig.width, page.selectedConfig.height) : ""
                onSelected: v => {
                    const r = DisplayFormat.parseResolution(v);
                    page.pickResolution(page.selectedName, r.width, r.height);
                }
            }
        }

        PageCard {
            id: refreshCard
            objectName: "displayCard:refresh"
            width: row.cardW
            height: page.rowH
            title: I18n.t("prefs.displays.refresh")
            value: page.selectedConfig ? DisplayFormat.formatHz(page.selectedConfig.refresh) : ""
            readonly property var draftOutput: page.selectedOutput && page.selectedConfig ? Object.assign({}, page.selectedOutput, page.selectedConfig) : null
            Column {
                width: parent.width
                spacing: Space.m
                enabled: page.active
                DisplayChips {
                    objectName: "refreshChips"
                    width: parent.width
                    options: refreshCard.draftOutput ? DisplayFormat.refreshOptions(page.selectedOutput, page.selectedConfig) : []
                    value: page.selectedConfig ? page.selectedConfig.refresh : 0
                    onSelected: v => page.edit(page.selectedName, {
                            "refresh": v
                        })
                }
                Chip {
                    objectName: "upgradeHint"
                    readonly property real best: refreshCard.draftOutput ? DisplayModel.bestRefresh(refreshCard.draftOutput) : 0
                    visible: !!refreshCard.draftOutput && DisplayModel.canUpgradeRefresh(refreshCard.draftOutput)
                    dense: true
                    icon: Icons.lightning
                    primary: true
                    text: I18n.t("prefs.displays.refresh_upgrade", DisplayFormat.formatHz(best))
                    onClicked: page.edit(page.selectedName, {
                        "refresh": best
                    })
                }
            }
        }

        PageCard {
            objectName: "displayCard:scale"
            width: row.cardW
            height: page.rowH
            title: I18n.t("prefs.displays.scale")
            value: page.selectedConfig ? DisplayFormat.formatScale(page.selectedConfig.scale) : ""
            DisplayScaleSteps {
                objectName: "scaleChips"
                anchors.fill: parent
                enabled: page.active
                options: page.selectedConfig ? DisplayFormat.scaleOptions(page.selectedConfig.scale, DisplayModel.suggestScale(page.selectedOutput || {})) : []
                value: page.selectedConfig ? page.selectedConfig.scale : 1
                onSelected: v => page.edit(page.selectedName, {
                        "scale": v
                    })
            }
        }

        PageCard {
            objectName: "displayCard:night"
            width: row.cardW
            height: page.rowH
            title: I18n.t("prefs.displays.night")
            value: NightLightClient.active ? NightLightClient.temp + " K" : I18n.t("prefs.displays.night_off")
            DisplayNightLight {
                anchors.fill: parent
            }
        }
    }
}
