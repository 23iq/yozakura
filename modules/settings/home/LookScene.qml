pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Look: the palette as overlapping swatches and a big
// "Aa" in the UI's heading font and accent.
Item {
    id: scene

    required property Card tile

    Row {
        spacing: -Space.m
        Repeater {
            model: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.surfaceContainerHighest]
            delegate: Mark {
                required property color modelData
                width: Space.controlM
                height: width
                color: modelData
                border.width: Space.stroke - 1
                border.color: Look.cardFill(false)
            }
        }
    }
    KitText {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -Space.s
        role: "display"
        font.pixelSize: Math.min(scene.height * 0.9, Type.size("display") * 1.6)
        font.weight: Font.DemiBold
        color: Type.accent
        text: "Aa"
    }
}
