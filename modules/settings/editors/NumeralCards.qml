import QtQuick
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals

// Workspace numerals (workspaces.numeralStyle) as picture cards: every
// registered system (WorkspaceNumerals.js) drawn by NumeralThumb.
Item {
    id: root

    property var entry

    implicitHeight: cards.implicitHeight

    CardSelector {
        id: cards
        width: parent.width
        entry: Object.assign({}, root.entry, {
            "thumb": "NumeralThumb"
        })
        options: WorkspaceNumerals.ids().map(id => ({
                    "value": id,
                    "label": "prefs.numerals." + id
                }))
        value: SettingsStore.get("workspaces.numeralStyle") || WorkspaceNumerals.DEFAULT_ID
        onSelected: v => SettingsStore.set("workspaces.numeralStyle", v)
    }
}
