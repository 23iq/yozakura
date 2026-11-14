pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.stages
import qs.modules.settings.store
import "../ChangesModel.js" as ChangesModel
import "../SchemaUtil.js" as SchemaUtil
import "../schema/Categories.js" as Categories

// "Changes", a list page: every setting that differs from its default (or,
// with a preset applied, from that preset), grouped by page, settings kept
// out of the window included. The band says how many and where (a chip
// per page), switches between "since defaults" and "since the preset", and
// holds the one primary action: put them all back (one undo step). The
// list fills the card under it; a row resets that one setting (live, one
// undo step) or opens it on its page (window rows only).
FittedFrame {
    id: page
    listForm: true
    hasHint: false

    required property var category
    // "defaults" | "preset" (only offered while a preset is applied)
    property string mode: "defaults"
    readonly property bool presetMode: page.mode === "preset" && PresetStatusService.active !== ""

    // Schema pages in sidebar order.
    readonly property var pages: Categories.groups.reduce((all, g) => all.concat(g.categories), []).map(id => Categories.byId(id)).filter(c => c && c.sections)
    readonly property var index: SchemaUtil.buildSearchIndex(Categories.categories, k => I18n.t(k))
    readonly property var groups: page.presetMode ? ChangesModel.fromPreset(PresetStatusService.changes, page.index, page.pages, k => I18n.t(k)) : ChangesModel.fromDefaults(page.pages, SettingsStore.resetContext, e => SettingsStore.isModified(e), k => SettingsStore.defaultValue(k), k => I18n.t(k))
    readonly property int total: ChangesModel.count(page.groups)

    function resetRow(change) {
        if (change.entry)
            SettingsStore.reset(change.entry);
        else if (change.key)
            SettingsStore.set(change.key, change.target);
    }

    // every row back, as one undo step
    function resetAll() {
        const rows = page.groups.reduce((all, g) => all.concat(g.rows), []);
        SettingsStore.transaction("prefs.undo.changes_reset", () => rows.forEach(r => page.resetRow(r)));
    }

    function open(change) {
        SettingsStore.navigate(change.categoryId, change.sectionId, change.entryId);
    }

    Component.onCompleted: PresetStatusService.refresh()

    // the band grows with its content (the summary and its chips are never
    // clipped); the chips stay on two lines, the rest behind "+N more"
    bandMin: Math.max(count.implicitHeight, summary.implicitHeight, actions.implicitHeight) + Space.l * 2
    // all chips shown ("+N more" clicked)
    property bool chipsOpen: false
    // how many chips fit on two lines (measured on the hidden flow)
    property int chipsFit: page.groups.length

    function measureChips() {
        const lineH = measureRep.count > 0 && measureRep.itemAt(0) ? measureRep.itemAt(0).height : 0;
        let fit = 0;
        for (let i = 0; i < measureRep.count; i++) {
            const it = measureRep.itemAt(i);
            if (it && it.y < lineH * 2 + Space.xs)
                fit++;
        }
        page.chipsFit = fit;
    }

    // the band: how many, where, since what, and the one action
    Stage {
        id: band
        calm: true
        readonly property bool fittedHero: true
        objectName: "changesBand"
        x: page.margin
        y: Space.s
        width: page.width - page.margin * 2
        height: page.bandH

        KitText {
            id: count
            x: Space.xl
            anchors.verticalCenter: parent.verticalCenter
            role: "display"
            font.pixelSize: Math.round(Type.size("display") * 1.5)
            font.weight: Font.Light
            color: page.total > 0 ? Type.accent : Type.text
            text: String(page.total)
        }
        Column {
            id: summary
            readonly property bool clipped: page.chipsFit < page.groups.length && !page.chipsOpen
            x: count.x + count.width + Space.l
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            width: Math.max(0, actions.x - x - Space.xl)
            KitText {
                objectName: "changesSummary"
                width: parent.width
                role: "title"
                wrapMode: Text.WordWrap
                text: page.total === 0 ? I18n.t(page.presetMode ? "prefs.changes.none_preset" : "prefs.changes.none") : I18n.tn("prefs.changes.band", page.total)
            }
            // where: a chip per page (two lines, then "+N more")
            Flow {
                objectName: "changesChips"
                width: parent.width
                spacing: Space.xs
                Repeater {
                    model: summary.clipped ? page.groups.slice(0, Math.max(0, page.chipsFit - 1)) : page.groups
                    delegate: Chip {
                        required property var modelData
                        dense: true
                        quiet: true
                        text: modelData.title + " · " + modelData.rows.length
                    }
                }
                Chip {
                    objectName: "changesMore"
                    visible: summary.clipped || page.chipsOpen
                    dense: true
                    text: page.chipsOpen ? I18n.t("prefs.changes.less") : I18n.t("prefs.changes.more", page.groups.length - Math.max(0, page.chipsFit - 1))
                    onClicked: page.chipsOpen = !page.chipsOpen
                }
            }
        }
        // the chips laid out at full length, unseen: how many fit
        Flow {
            id: measure
            width: summary.width
            opacity: 0
            enabled: false
            spacing: Space.xs
            onPositioningComplete: page.measureChips()
            onWidthChanged: Qt.callLater(page.measureChips)
            Repeater {
                id: measureRep
                model: page.groups
                delegate: Chip {
                    required property var modelData
                    dense: true
                    quiet: true
                    text: modelData.title + " · " + modelData.rows.length
                }
            }
        }
        Column {
            id: actions
            x: band.width - width - Space.xl
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            Segmented {
                objectName: "changesMode"
                anchors.right: parent.right
                visible: PresetStatusService.active !== ""
                model: [
                    {
                        "name": "mode:defaults",
                        "icon": Icons.arrowCounterClockwise,
                        "text": I18n.t("prefs.changes.since_defaults")
                    },
                    {
                        "name": "mode:preset",
                        "icon": Icons.magicWand,
                        "text": I18n.t("prefs.changes.since_preset", PresetStatusService.active)
                    }
                ]
                currentIndex: page.presetMode ? 1 : 0
                onActivated: i => page.mode = i === 1 ? "preset" : "defaults"
            }
            // destructive: the danger look, never the accent (one undo step
            // brings everything back: the undo pill offers it)
            Chip {
                objectName: "changesResetAll"
                anchors.right: parent.right
                visible: page.total > 0
                danger: true
                active: true
                icon: Icons.arrowCounterClockwise
                text: I18n.t(page.presetMode ? "prefs.changes.back_to_preset" : "prefs.changes.back_to_defaults")
                onClicked: page.resetAll()
            }
        }
    }

    // the list, in one tall card
    Card {
        id: listCard
        readonly property bool fittedCard: true
        objectName: "changesList"
        x: page.margin
        y: band.y + band.height + page.gap
        width: page.width - page.margin * 2
        height: page.height - y - page.pad
        padding: Look.boxPadding + Space.s

        // the list runs on under the card's foot (masked fade, no second box)
        EdgeFade {
            width: listCard.contentWidth
            height: listCard.height - listCard.padding
            start: flick.contentY > 1 ? Space.l : 0
            end: flick.contentY < flick.contentHeight - flick.height - 1 ? Space.xl : 0

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: column.implicitHeight + listCard.padding
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Column {
                    id: column
                    width: flick.width
                    spacing: Look.groupGap

                    // nothing changed: a calm card with a check (the band says it)
                    Column {
                        visible: page.total === 0
                        width: parent.width
                        topPadding: Space.xxl * 2
                        spacing: Space.m
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: Icons.checkCircle
                            size: Space.controlL
                            tone: "accent"
                        }
                    }

                    Repeater {
                        model: page.groups

                        // the card is the one box: groups are bare
                        delegate: Group {
                            id: groupItem
                            labelRole: "group"
                            required property var modelData
                            required property int index
                            bare: true
                            width: column.width
                            label: modelData.title
                            divider: index > 0

                            Repeater {
                                model: groupItem.modelData.rows

                                delegate: ChangeRow {
                                    required property var modelData
                                    width: parent ? parent.width : 0
                                    change: modelData
                                    valuesKey: page.presetMode ? "prefs.changes.vs_preset" : "prefs.changes.vs_default"
                                    onResetRequested: page.resetRow(modelData)
                                    onJumpRequested: page.open(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
