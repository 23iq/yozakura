pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// What the Assistant's status strip shows (ai.strip.*): one chip per item,
// lit while it is on; a click turns it on or off. Under the pointer a chip
// lights up the strip on the stage.
Flow {
    id: root

    property var entry
    readonly property var items: [
        {
            "key": "engine",
            "icon": "sparkle",
            "label": "prefs.ai.strip_chip.engine"
        },
        {
            "key": "effort",
            "icon": "brain",
            "label": "prefs.ai.strip_chip.effort"
        },
        {
            "key": "context",
            "icon": "circleHalf",
            "label": "prefs.ai.strip_chip.context"
        },
        {
            "key": "cost",
            "icon": "chartBar",
            "label": "prefs.ai.strip_chip.cost"
        },
        {
            "key": "limit",
            "icon": "hourglass",
            "label": "prefs.ai.strip_chip.limit"
        }
    ]

    spacing: Space.s

    Repeater {
        model: root.items
        delegate: Chip {
            id: chip
            required property var modelData
            readonly property string key: "ai.strip." + chip.modelData.key
            objectName: "stripChip:" + chip.modelData.key
            icon: Icons[chip.modelData.icon] ?? ""
            text: I18n.t(chip.modelData.label)
            active: SettingsStore.get(chip.key) !== false
            onClicked: SettingsStore.set(chip.key, !chip.active)
            onHoveredChanged: chip.hovered ? SettingsStore.point(chip, [chip.key]) : SettingsStore.unpoint(chip)
            Component.onDestruction: SettingsStore.unpoint(chip)
        }
    }
}
