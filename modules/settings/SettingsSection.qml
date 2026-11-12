pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "Ui.js" as Ui
import "SchemaUtil.js" as SchemaUtil

// One schema section as a bento card (kit Card): its title as the card's
// label over one SettingRow per entry that is in the window
// (SchemaUtil.inWindow: no row object exists for an out-of-window entry).
// The card shows only while one of its rows does
// (SettingsStore.sectionShown: compositor gate, visibleWhen).
Card {
    id: sectionRoot

    required property var section
    readonly property string sectionId: section.id
    readonly property var entries: (section.entries || []).filter(e => SchemaUtil.inWindow(e, section))
    readonly property bool shown: SettingsStore.sectionShown(section)
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
    label: section.title ? I18n.t(section.title) : ""
    padding: Look.boxPadding
    spacing: Space.s

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
                previousEntry: index > 0 ? sectionRoot.entries[index - 1] : null
            }
        }
    }
}
