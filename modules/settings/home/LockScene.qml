pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages

// Home tile scene of Lock screen: the wallpaper dimmed as the lock shows
// it (zoomed in a little, like the lock's own backdrop), and the clock.
Stage {
    id: scene

    required property Card tile

    stageHeight: height
    radius: scene.tile.radius
    imageScale: scene.tile.hovered ? 1.3 : 1.22

    Mark {
        anchors.fill: parent
        radius: scene.radius
        color: Qt.alpha(Colors.shadow, 0.3)
    }
    KitText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        role: "display"
        font.weight: Font.Light
        color: Qt.rgba(1, 1, 1, 0.94)
        text: "21:47"
    }
    NameScrim {}
}
