pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config

// Rounded cava bars with a primary -> tertiary palette gradient.
// Size is fixed by the parent; bars only change their own height, so the
// island never resizes with the audio. Registers with CavaService only while
// it is actually on screen and the player is playing.
Item {
    id: root

    property int barCount: 6
    property real spacing: 2
    property real preferredBarWidth: 3
    // true: bars grow from the vertical centre; false: from the bottom edge.
    property bool centered: true
    property bool playing: false
    // External visibility gate (e.g. the island is slid off screen).
    property bool shown: true
    // Opacity of the flat bars while idle.
    property real idleOpacity: 0.35
    // The owner's visualizer setting (the lock screen has its own).
    property bool configEnabled: Config.notch?.visualizer ?? true

    // An active battery saver keeps it from registering, so cava can stop.
    readonly property bool active: configEnabled && playing && shown && visible && CavaService.available && !BatterySaver.active
    readonly property real barWidth: Math.max(1, (width - spacing * (barCount - 1)) / barCount)
    readonly property var levels: active ? CavaService.levels(barCount) : []
    // Levels as drawn: eased once per cava frame instead of a height
    // Behavior. A Behavior retargeted by every frame keeps an animation
    // running nonstop, which repaints the window at the output refresh rate
    // (240 Hz on a 240 Hz monitor) instead of cava's frame rate. A frame
    // that moves no bar (settled silence) leaves `drawn` alone: no redraw.
    property var drawn: []
    // Share of the distance covered per frame. The previous 70 ms OutQuad
    // retargeted every 16.7 ms covered 0.42 per 60 fps frame
    // (1 - (1 - 16.7 / 70)^2); scaled to cava's rate so the bars keep that
    // speed (0.66 per frame at 30 fps).
    readonly property real easing: Config.animDuration > 0 ? 1 - Math.pow(1 - 0.42, 60 / Math.max(1, CavaService.framerate || 60)) : 1
    onLevelsChanged: {
        if (!levels.length) {
            if (drawn.length)
                drawn = [];
            return;
        }
        const next = ease(drawn, levels, easing);
        if (next)
            drawn = next;
    }

    // Bars closer than this to their target snap onto it (1/500 of the
    // height), so the easing ends instead of creeping forever.
    readonly property real settleEpsilon: 0.002

    // One frame of easing toward `target`; bars without a previous value
    // start at the target. Returns null when no bar moves, else a new array
    // (allocated only then), so bindings on `drawn` see a fresh reference.
    function ease(prev, target, k) {
        const n = target.length;
        const p = prev || [];
        let out = null;
        for (let i = 0; i < n; i++) {
            const has = i < p.length;
            let v = !has || k >= 1 ? target[i] : p[i] + (target[i] - p[i]) * k;
            if (Math.abs(target[i] - v) < settleEpsilon)
                v = target[i];
            if (out === null && (!has || v !== p[i]))
                out = p.slice(0, i);
            if (out !== null)
                out.push(v);
        }
        if (out === null && p.length !== n)
            out = p.slice(0, n);
        return out;
    }
    property color startColor: Colors.primary
    property color endColor: Colors.tertiary
    property string _consumerKey: ""

    implicitWidth: barCount * preferredBarWidth + (barCount - 1) * spacing

    function barColor(index) {
        const t = barCount > 1 ? index / (barCount - 1) : 0;
        return Qt.rgba(startColor.r + (endColor.r - startColor.r) * t, startColor.g + (endColor.g - startColor.g) * t, startColor.b + (endColor.b - startColor.b) * t, 1);
    }

    onActiveChanged: CavaService.setConsumer(_consumerKey, active)
    Component.onCompleted: {
        _consumerKey = "notch-visualizer-" + Date.now().toString(36) + Math.random().toString(36).slice(2);
        CavaService.setConsumer(_consumerKey, active);
    }
    Component.onDestruction: CavaService.setConsumer(_consumerKey, false)

    Repeater {
        model: root.barCount

        Rectangle {
            id: bar
            required property int index
            readonly property real level: root.drawn[bar.index] ?? 0

            x: bar.index * (root.barWidth + root.spacing)
            y: root.centered ? (root.height - bar.height) / 2 : root.height - bar.height
            width: root.barWidth
            // Never thinner than wide, so silent bars are round dots.
            height: Math.max(bar.width, Math.min(root.height, bar.level * root.height))
            radius: bar.width / 2
            color: root.barColor(bar.index)
            opacity: root.active ? 0.95 : root.idleOpacity
            antialiasing: true

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Math.min(Config.animDuration, 200) }
            }
        }
    }
}
