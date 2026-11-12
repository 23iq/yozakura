pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Around sleep, as two switches instead of two shell commands: lock before
// sleeping (system.idle.general.before_sleep_cmd) and wake the screen after
// (after_sleep_cmd). A switch turned on writes the default command, off
// clears it; a custom command reads as on and stays until turned off. The
// raw commands stay reachable through `yozakura config`.
Column {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var items: [
        {
            "key": "system.idle.general.before_sleep_cmd",
            "label": "prefs.power.lock_before_sleep",
            "icon": Icons.lock,
            "command": "loginctl lock-session"
        },
        {
            "key": "system.idle.general.after_sleep_cmd",
            "label": "prefs.power.wake_screen",
            "icon": Icons.monitor,
            "command": "yozakura screen on"
        }
    ]

    spacing: Space.s

    Repeater {
        model: root.items
        delegate: Item {
            id: item
            required property var modelData
            readonly property bool on: String(SettingsStore.get(modelData.key) || "").trim() !== ""
            objectName: "sleepSwitch:" + modelData.key
            width: root.width
            height: Space.controlM

            Icon {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                icon: item.modelData.icon
                role: "body"
                tone: item.on ? "accent" : "muted"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: glyph.right
                anchors.leftMargin: Space.m
                anchors.right: toggle.left
                anchors.rightMargin: Space.s
                role: "body"
                elide: Text.ElideRight
                text: I18n.t(item.modelData.label)
            }
            Switch {
                id: toggle
                objectName: "sleepToggle:" + item.modelData.key
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: item.on
                onToggled: v => SettingsStore.set(item.modelData.key, v ? item.modelData.command : "")
            }
        }
    }
}
