import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The shared element between home and a page (SettingsShell). While
// `active`, a frame travels between `origin` (the tile's rect, in this
// item's coordinates) at `t` = 0 and the whole item at `t` = 1. Inside it
// the page (the default children, laid out at full size) is drawn scaled
// to cover the frame and clipped to it, so the page itself grows out of the
// tile and shrinks back into it; over it a snapshot of the tile
// (`capture(item)`: a ShaderEffectSource of the real tile, which is hidden
// while its stand-in shows) grows evenly with the frame and cross-fades
// with the page (`pageFade` is the page's share). Under both, a card of the
// language grows with them and gives way at the ends. Inactive, the page
// is drawn as is: no clip, no transform, nothing over it.
Item {
    id: morph

    property real t: 1
    property var origin: null
    property bool active: false
    // 0..1: how much of the page shows (the rest is the tile's snapshot)
    property real pageFade: 1
    default property alias content: inner.data
    // what the snapshot holds (null: none, the page grows from the card alone)
    readonly property Item source: snap.sourceItem

    // the frame: from the origin (the middle without one) to the whole item
    readonly property var o: morph.origin || {
        "x": morph.width * 0.4,
        "y": morph.height * 0.4,
        "w": morph.width * 0.2,
        "h": morph.height * 0.2
    }
    readonly property real fx: morph.active ? morph.o.x * (1 - morph.t) : 0
    readonly property real fy: morph.active ? morph.o.y * (1 - morph.t) : 0
    readonly property real fw: morph.active ? morph.o.w + (morph.width - morph.o.w) * morph.t : morph.width
    readonly property real fh: morph.active ? morph.o.h + (morph.height - morph.o.h) * morph.t : morph.height
    // the page's scale: it covers the frame
    readonly property real s: morph.active && morph.width > 0 && morph.height > 0 ? Math.max(morph.fw / morph.width, morph.fh / morph.height) : 1
    // the tile's corner radius at the start, square at the end
    readonly property real startRadius: Look.bigRadius(Space.controlXL)
    // room around the tile in its snapshot (its lift and shadow)
    readonly property real margin: Space.xxl

    // Takes the snapshot of `item` (null: none) for the next transition.
    function capture(item) {
        snap.sourceItem = item || null;
        if (item)
            snap.scheduleUpdate();
    }

    // the card under the travelling frame: none at the ends (the tile has
    // its own, the page stands on the window), full in the middle
    Mark {
        visible: morph.active && opacity > 0
        x: morph.fx
        y: morph.fy
        width: morph.fw
        height: morph.fh
        radius: morph.startRadius * (1 - morph.t)
        color: Look.cardFill(false)
        opacity: Math.min(1, morph.t / 0.3) * Math.min(1, (1 - morph.t) / 0.4)
    }

    Item {
        id: frame
        x: morph.fx
        y: morph.fy
        width: morph.fw
        height: morph.fh
        clip: morph.active

        Item {
            id: inner
            width: morph.width
            height: morph.height
            transform: [
                Translate {
                    x: morph.active ? -morph.width / 2 : 0
                    y: morph.active ? -morph.height / 2 : 0
                },
                Scale {
                    xScale: morph.s
                    yScale: morph.s
                },
                Translate {
                    x: morph.active ? morph.fw / 2 : 0
                    y: morph.active ? morph.fh / 2 : 0
                }
            ]
        }
    }

    // the tile's stand-in, stretched with the frame
    ShaderEffectSource {
        id: snap
        objectName: "morphSnapshot"
        visible: morph.active && snap.sourceItem !== null && opacity > 0
        hideSource: morph.active
        live: false
        sourceRect: Qt.rect(-morph.margin, -morph.margin, morph.o.w + morph.margin * 2, morph.o.h + morph.margin * 2)
        // scaled evenly (never stretched: a wide result row would smear),
        // as large as the frame holds, centred in it
        readonly property real k: morph.o.w > 0 && morph.o.h > 0 ? Math.min(morph.fw / morph.o.w, morph.fh / morph.o.h) : 1
        width: (morph.o.w + morph.margin * 2) * snap.k
        height: (morph.o.h + morph.margin * 2) * snap.k
        x: morph.fx + morph.fw / 2 - width / 2
        y: morph.fy + morph.fh / 2 - height / 2
        // gone a little before the page is whole (no double image at the end)
        opacity: 1 - Math.min(1, morph.pageFade * 1.5)
    }
}
