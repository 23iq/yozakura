pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages

// Home tile scene of Desktop layout: the real screen miniature (the same
// ScreenMini the page's stage uses) on your wallpaper.
Stage {
    id: scene

    required property Card tile

    stageHeight: height
    radius: scene.tile.radius
    imageScale: scene.tile.hovered ? 1.06 : 1
    imageShift: Qt.point(-scene.tile.pointer.x * Space.m, -scene.tile.pointer.y * Space.s)

    ScreenMini {
        anchors.fill: parent
        anchors.margins: Space.s
        // the dock stays clear of the name under it
        anchors.bottomMargin: scene.tile.padding + Space.controlL
        corners: false
        cornerRadius: scene.tile.radius
        barOpacity: scene.barOpacity
    }
    NameScrim {}
}
