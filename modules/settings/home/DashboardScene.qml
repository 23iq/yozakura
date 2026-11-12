pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Dashboard: a media progress strip over a widget grid
// (two small widgets, one wide).
Item {
    id: scene

    required property Card tile
    readonly property real gap: Space.s
    readonly property real half: (scene.width - scene.gap) / 2

    ProgressLine {
        width: scene.width
        value: 0.55
    }
    Mark {
        y: Space.l
        width: scene.half
        height: Space.controlM
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
    }
    Mark {
        x: scene.half + scene.gap
        y: Space.l
        width: scene.half
        height: Space.controlM
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
    }
    Mark {
        y: Space.l + Space.controlM + scene.gap
        width: scene.width
        height: Math.min(Space.controlL, scene.height - y)
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
    }
}
