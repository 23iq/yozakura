pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages

// Home tile scene of Wallpaper: the wallpaper, swelling and following the
// pointer while hovered.
Stage {
    id: scene

    required property Card tile

    stageHeight: height
    radius: scene.tile.radius
    imageScale: scene.tile.hovered ? 1.08 : 1
    imageShift: Qt.point(-scene.tile.pointer.x * Space.m, -scene.tile.pointer.y * Space.s)

    NameScrim {}
}
