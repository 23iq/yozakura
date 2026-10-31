pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.store
import "../ChangesModel.js" as ChangesModel
import "../SchemaUtil.js" as SchemaUtil
import "../schema/Categories.js" as Categories

// "Changes": every setting that differs from its default (or, with a preset
// applied, from that preset), grouped by page. A row resets that one
// setting (through SettingsStore: staged like any edit, Discard undoes it)
// or opens it on its page.
Flickable {
    id: page

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

    function open(change) {
        SettingsStore.navigate(change.categoryId, change.sectionId, change.entryId);
    }

    Component.onCompleted: PresetStatusService.refresh()

    contentWidth: width
    contentHeight: column.implicitHeight + Space.xxl * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    Column {
        id: column
        width: Math.min(page.width - Space.xxl * 2, 820)
        x: (page.width - width) / 2
        y: Space.xxl
        spacing: Look.groupGap

        PageHeader {
            width: parent.width
            category: page.category
        }

        Segmented {
            objectName: "changesMode"
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

        KitText {
            objectName: "changesSummary"
            width: parent.width
            role: "secondary"
            wrapMode: Text.WordWrap
            text: page.total === 0 ? I18n.t(page.presetMode ? "prefs.changes.none_preset" : "prefs.changes.none") : I18n.tn("prefs.changes.count", page.total)
        }

        Repeater {
            model: page.groups

            delegate: Group {
                id: groupItem
                required property var modelData
                required property int index
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
