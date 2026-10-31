pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Snow on a surface (theme.weatherFx.frost while it snows): now and then a
// flake drifts down and settles along the top edge; once the edge is full
// the oldest one melts to make room. Starts with a few flakes resting; one
// timer (the flakes step on WeatherFx.frame), stopped while hidden or with motion off.
Item {
    id: root

    property real level: 0.5
    property real strength: 1
    property bool animate: false
    property int salt: 0
    property real radius: 0

    readonly property int slots: WeatherFx.flakeSlots(root.level, root.width)
    property var rand: WeatherFx.rng(root.salt + 23)

    Repeater {
        id: flakes
        model: root.slots
        SnowFlake {
            required property int index
            readonly property real jitter: root.rand() - 0.5
            d: Space.xs * (0.8 + Math.abs(jitter) * 0.8)
            restX: Math.max(root.radius * 0.6, Math.min(root.width - d - root.radius * 0.6, (index + 0.5 + jitter * 0.7) / root.slots * root.width))
            restY: Space.hairline + Math.abs(jitter) * Space.xs * 0.5
            strength: root.strength
            animate: root.animate
            // Resting from the start: every other flake (fewer while it can
            // still fill up with motion)
            settled: index % (root.animate ? 3 : 2) === 0
        }
    }

    Timer {
        objectName: "snowTimer"
        running: root.animate && flakes.count > 0
        repeat: true
        interval: WeatherFx.cadence("snow", root.level)
        onTriggered: {
            interval = Math.round(WeatherFx.cadence("snow", root.level) * (0.6 + root.rand() * 0.8));
            // A random spot: an empty one fills, a resting flake is replaced
            const f = flakes.itemAt(Math.floor(root.rand() * flakes.count)) as SnowFlake;
            if (f)
                f.fall();
        }
    }
}
