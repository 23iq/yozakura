pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.settings.controls
import qs.modules.settings.store
import "../SchemaUtil.js" as SchemaUtil

// Power > More settings > Idle commands: the raw idle listeners (a shell
// command after a timeout); the idle timeline is how most people set these,
// so they live in the tab's More card (the section is advanced).
// `entry.list` is the list entry shown (ListControl: one card a listener,
// add / remove / reorder). Writes system.idle.listeners live.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var listEntry: (root.entry && root.entry.list) || ({})
    readonly property var items: SchemaUtil.plain(SettingsStore.get(root.listEntry.key || "system.idle.listeners")) || []

    implicitHeight: list.implicitHeight

    ListControl {
        id: list
        objectName: "idleCommandsList"
        width: root.width
        entry: root.listEntry
        // the fields first: before them a listener would read as a string
        items: (root.listEntry.fields || []).length > 0 ? root.items : []
        onChanged: v => SettingsStore.set(root.listEntry.key || "system.idle.listeners", v)
    }
}
