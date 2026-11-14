pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "../SchemaUtil.js" as SchemaUtil

// Power > Advanced: the raw idle listeners (a shell command after a
// timeout) folded under a disclosure, closed by default: the idle timeline
// is how most people set these. `entry.list` is the list entry the editor
// shows when open (ListControl: one card a listener, add / remove /
// reorder). Writes system.idle.listeners live.
Column {
    id: root

    property var entry
    property real fillHeight: 0
    property bool open: false
    readonly property var listEntry: (root.entry && root.entry.list) || ({})
    readonly property var items: SchemaUtil.plain(SettingsStore.get(root.listEntry.key || "system.idle.listeners")) || []

    spacing: Space.s

    PillButton {
        objectName: "idleCommandsToggle"
        x: Math.max(0, Look.rowInset - Space.m)
        kind: "ghost"
        icon: root.open ? "caretUp" : "caretDown"
        text: I18n.t("prefs.power.commands_toggle", root.items.length)
        Accessible.role: Accessible.Button
        Accessible.description: I18n.t(root.open ? "common.close" : "common.open")
        onClicked: root.open = !root.open
    }

    // built while closed (it holds the add / reset actions), shown open
    ListControl {
        objectName: "idleCommandsList"
        width: root.width
        visible: root.open
        height: root.open ? implicitHeight : 0
        entry: root.listEntry
        // the fields first: before them a listener would read as a string
        items: (root.listEntry.fields || []).length > 0 ? root.items : []
        onChanged: v => SettingsStore.set(root.listEntry.key || "system.idle.listeners", v)
    }
}
