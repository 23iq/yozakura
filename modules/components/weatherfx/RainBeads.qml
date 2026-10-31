pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Rain on a surface (theme.weatherFx.rain): a few drops resting where they
// landed (more in heavy rain than in drizzle, WeatherFxModel.beadCount) and,
// every few seconds, one of them running down. One timer per surface; it
// stops while the surface is hidden or motion is off (the drops then just
// rest).
Item {
    id: root

    property real level: 0.5
    property real strength: 1
    property bool animate: false
    property int salt: 0
    property real radius: 0

    readonly property int count: WeatherFx.beadCount(root.level, root.width * root.height)
    // Where the drops rest, and a fine mist of tiny static droplets between
    // them; laid out again only when the surface size or the rain changes
    readonly property var layout: root.compute(root.count, root.width, root.height)
    readonly property var spots: root.layout.spots
    readonly property var mist: root.layout.mist
    // Randomness of the running drops and their next landing spots
    property var rand: WeatherFx.rng(root.salt + 13)

    function spot(r: var, w: real, h: real): var {
        const d = Math.min(h * 0.2, Space.s * (0.6 + Math.pow(r(), 2) * 1.3) * (root.strength > 1.2 ? 1.12 : 1));
        return {
            x: root.radius * 0.3 + r() * Math.max(0, w - d - root.radius * 0.6),
            y: r() * Math.max(0, h - d * 1.2),
            d: d
        };
    }

    function compute(count: int, w: real, h: real): var {
        const r = WeatherFx.rng(root.salt + 11);
        const out = [];
        for (let i = 0; i < count; i++)
            out.push(root.spot(r, w, h));
        const fine = [];
        for (let i = 0; i < Math.min(64, count * 4); i++)
            fine.push({
                x: root.radius * 0.3 + r() * Math.max(0, w - root.radius * 0.6),
                y: r() * h,
                s: 1.5 + r() * 1.5,
                a: 0.14 + r() * 0.22
            });
        return {
            spots: out,
            mist: fine
        };
    }

    // A drop that ran off lands again in the upper part of the surface
    function landing(): var {
        const p = root.spot(root.rand, root.width, root.height);
        p.y = p.y * 0.6;
        return p;
    }

    Repeater {
        model: root.mist
        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.s
            height: modelData.s
            radius: width / 2
            color: Qt.alpha(WeatherFx.glint, Math.min(1, modelData.a * root.strength))
        }
    }

    Repeater {
        id: drops
        model: root.spots.length
        RainDrop {
            required property int index
            readonly property var spot: root.spots[index] || ({
                    x: 0,
                    y: 0,
                    d: Space.xs
                })
            x: spot.x
            y: spot.y
            d: spot.d
            strength: root.strength
            respawn: root.landing
            clock: slideClock
            onMoving: on => root.movers += on ? 1 : -1
        }
    }

    // One 20 Hz clock for every sliding drop of this surface, running only
    // while one slides
    property int movers: 0
    Timer {
        id: slideClock
        interval: 50
        repeat: true
        running: root.movers > 0
    }

    Timer {
        objectName: "rainTimer"
        running: root.animate && drops.count > 0
        repeat: true
        interval: WeatherFx.cadence("rain", root.level)
        onTriggered: {
            interval = Math.round(WeatherFx.cadence("rain", root.level) * (0.6 + root.rand() * 0.8));
            const i = Math.floor(root.rand() * drops.count);
            const drop = drops.itemAt(i) as RainDrop;
            if (drop)
                drop.run();
        }
    }
}
