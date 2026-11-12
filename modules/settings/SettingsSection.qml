pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "Ui.js" as Ui
import "SchemaUtil.js" as SchemaUtil
import "ChangesModel.js" as ChangesModel

// One schema section as a bento card (kit Card): a heading (the section
// title) with the current value on the right when the card holds one
// setting ("Shape ... Classic"), over one SettingRow per entry that is in
// the window (SchemaUtil.inWindow: no row object exists for an
// out-of-window entry) and not shown beside the stage (`exclude`). A card
// of one picture / editor setting drops the row's own label (the heading
// names it). The card shows only while one of its rows does
// (SettingsStore.sectionShown: compositor gate, visibleWhen).
Card {
    id: sectionRoot

    required property var section
    // entry keys / ids shown elsewhere (beside the stage)
    property var exclude: []
    readonly property string sectionId: section.id
    readonly property var entries: (section.entries || []).filter(e => SchemaUtil.inWindow(e, section) && sectionRoot.exclude.indexOf(e.key || e.id) < 0)
    readonly property bool shown: sectionRoot.entries.length > 0 && SettingsStore.sectionShown(section)
    // one setting: its value beside the heading, no label of its own
    readonly property var single: sectionRoot.entries.length === 1 ? sectionRoot.entries[0] : null
    readonly property string value: {
        const e = sectionRoot.single;
        if (!e || !e.key || e.type === "toggle")
            return "";
        const v = SettingsStore.get(e.key);
        return v === undefined || v === null || typeof v === "object" || typeof v === "boolean" ? "" : ChangesModel.describe(e, v, k => I18n.t(k));
    }
    // Not built yet: the page fills its sections in a few per frame.
    property bool pending: false

    function rowFor(entryId) {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (Ui.prop(r, "entryId") === entryId)
                return r;
        }
        return null;
    }

    objectName: "settingsSection:" + sectionId
    visible: sectionRoot.shown && !sectionRoot.pending
    padding: Look.boxPadding + Space.s
    spacing: Space.s

    Item {
        width: sectionRoot.contentWidth
        height: Math.max(heading.implicitHeight, valueText.implicitHeight)
        visible: heading.text !== ""

        KitText {
            id: heading
            objectName: "sectionHeading"
            width: parent.width - (valueText.visible ? valueText.implicitWidth + Space.m : 0)
            role: "title"
            text: sectionRoot.section.title ? I18n.t(sectionRoot.section.title) : ""
            elide: Text.ElideRight
        }
        KitText {
            id: valueText
            objectName: "sectionValue"
            anchors.right: parent.right
            anchors.verticalCenter: heading.verticalCenter
            visible: sectionRoot.value !== ""
            role: "secondary"
            text: sectionRoot.value
        }
    }

    Column {
        id: rowsColumn
        width: sectionRoot.contentWidth
        spacing: 0

        Repeater {
            id: rows
            model: sectionRoot.pending || !sectionRoot.shown ? [] : sectionRoot.entries

            delegate: SettingRow {
                required property var modelData
                required property int index
                width: rowsColumn.width
                entry: modelData
                bare: sectionRoot.single !== null
                previousEntry: index > 0 ? sectionRoot.entries[index - 1] : null
            }
        }
    }
}
