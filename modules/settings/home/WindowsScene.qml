pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Windows: tiled window outlines with the configured gap
// and border, the focused one in the accent.
Item {
    id: scene

    required property Card tile
    readonly property real gap: Math.max(Space.hairline, Math.min(Space.m, Number(SettingsStore.get("compositor.gapsIn") ?? 4)))
    readonly property real border: Math.max(Space.hairline, Math.min(Space.xs, Number(SettingsStore.get("compositor.borderSize") ?? 2)))
    readonly property real w: Math.min(scene.width, scene.height * 1.4)

    Item {
        anchors.right: parent.right
        width: scene.w
        height: scene.height
        Repeater {
            model: [[0, 0, 0.5, 1], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]
            delegate: Mark {
                required property var modelData
                required property int index
                x: modelData[0] * scene.w + (index > 0 ? scene.gap / 2 : 0)
                y: modelData[1] * scene.height + (modelData[1] > 0 ? scene.gap / 2 : 0)
                width: modelData[2] * scene.w - scene.gap / 2
                height: modelData[3] * scene.height - (modelData[3] < 1 ? scene.gap / 2 : 0)
                radius: Look.radius("box", height)
                color: Look.raisedFill(false)
                border.width: scene.border
                border.color: index === 0 ? Type.accent : Qt.alpha(Colors.outlineVariant, 0.6)
            }
        }
    }
}
