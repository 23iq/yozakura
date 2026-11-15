pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages

// Home tile scene of Screen: your whole screen as a small monitor standing
// on the card (16:9 in a thin bezel, on a neck and a foot, fitted and
// centred in the scene): the real screen miniature (the same ScreenMini the
// page's stage uses) on your wallpaper, every bar, the island and the dock
// in view, a soft shadow under it. The card around it is the language's
// own box, so the name under or beside it reads on any wallpaper and in
// light themes. A short scene drops the stand.
Item {
    id: scene

    required property Card tile

    // the stand under the monitor, a share of its height
    readonly property bool stand: scene.height >= Space.px(120)
    readonly property real standShare: scene.stand ? 0.16 : 0
    readonly property real bezel: Math.max(Space.hairline * 2, Math.round(scene.height * 0.02))
    // the monitor: 16:9, as large as the scene holds with its stand
    readonly property real monitorWidth: Math.min(scene.width - scene.bezel * 2, scene.height / (1 + scene.standShare) * scene.tile.monitorAspect)
    readonly property real monitorHeight: scene.monitorWidth / scene.tile.monitorAspect
    readonly property real standHeight: Math.round(scene.monitorHeight * scene.standShare)

    // the stand: a neck and a foot
    Mark {
        visible: scene.stand
        x: Math.round((scene.width - width) / 2)
        y: bezelBox.y + bezelBox.height - Space.hairline
        width: Math.round(scene.monitorWidth * 0.09)
        height: Math.round(scene.standHeight * 0.75)
        radius: 0
        color: Look.raisedFill(false)
    }
    Mark {
        visible: scene.stand
        x: Math.round((scene.width - width) / 2)
        y: bezelBox.y + bezelBox.height + Math.round(scene.standHeight * 0.7)
        width: Math.round(scene.monitorWidth * 0.3)
        height: Math.max(Space.xs, Math.round(scene.standHeight * 0.3))
        radius: Look.radius("small", height)
        color: Look.raisedFill(false)
        border.width: Space.hairline
        border.color: Type.hairline
    }

    RectangularShadow {
        anchors.fill: bezelBox
        radius: bezelBox.radius
        offset: Qt.vector2d(0, Space.xs)
        blur: Space.l
        spread: 0
        color: Look.cardShadow
    }

    // the bezel
    Mark {
        id: bezelBox
        x: monitor.x - scene.bezel
        y: monitor.y - scene.bezel
        width: monitor.width + scene.bezel * 2
        height: monitor.height + scene.bezel * 2
        radius: monitor.radius + scene.bezel
        color: Colors.background
        border.width: Space.hairline
        border.color: Look.cardEdge.a > 0 ? Look.cardEdge : Type.hairline
    }

    Stage {
        id: monitor
        x: Math.round((scene.width - width) / 2)
        y: Math.round((scene.height - height - scene.standHeight) / 2)
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
