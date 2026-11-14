pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages

// Home tile scene of Screen: your whole screen as a small monitor on the
// card (16:9, fitted and centred in the scene with room around it): the
// real screen miniature (the same ScreenMini the page's stage uses) on your
// wallpaper, every bar, the island and the dock in view, a soft shadow
// under it. The card around it is the language's own box, so the name
// under or beside it reads on any wallpaper and in light themes.
Item {
    id: scene

    required property Card tile

    // the monitor: 16:9, as large as the scene holds
    readonly property real monitorWidth: Math.min(scene.width, scene.height * scene.tile.monitorAspect)
    readonly property real monitorHeight: scene.monitorWidth / scene.tile.monitorAspect

    RectangularShadow {
        anchors.fill: monitor
        radius: monitor.radius
        offset: Qt.vector2d(0, Space.xs)
        blur: Space.l
        spread: 0
        color: Look.cardShadow
    }

    Stage {
        id: monitor
        x: Math.round((scene.width - width) / 2)
        y: Math.round((scene.height - height) / 2)
        width: Math.round(scene.monitorWidth)
        height: Math.round(scene.monitorHeight)
        stageHeight: height
        radius: Look.radius("small", height)
        imageScale: scene.tile.hovered ? 1.06 : 1
        imageShift: Qt.point(-scene.tile.pointer.x * Space.s, -scene.tile.pointer.y * Space.xs)

        ScreenMini {
            anchors.fill: parent
            corners: false
            cornerRadius: monitor.radius
            barOpacity: monitor.barOpacity
        }
    }
}
