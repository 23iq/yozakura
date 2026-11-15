pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "../stages/WindowTiles.js" as Tiles

// Card picture of a tiling layout (compositor.layout): the windows the
// layout makes on a small screen (WindowTiles, as on the stage), the
// focused one in the accent.
MiniScreen {
    id: root

    property var entry
    property var value: "dwindle"
    readonly property var tiles: Tiles.tiles(String(root.value), root.width, root.height, root.u * 1.2, root.u * 4)

    Repeater {
        model: root.tiles
        delegate: Mark {
            required property var modelData
            required property int index
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            radius: Space.smallRadius / 2
            color: Qt.alpha(index === 0 ? Colors.background : Colors.surfaceContainer, 0.88)
            border.width: index === 0 ? 2 : Space.hairline
            border.color: index === 0 ? Type.accent : Qt.alpha(Colors.outlineVariant, 0.7)
        }
    }
}
