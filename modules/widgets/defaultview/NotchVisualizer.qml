pragma ComponentBehavior: Bound

import QtQuick
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

    readonly property bool active: configEnabled && playing && shown && visible && CavaService.available
    readonly property real barWidth: Math.max(1, (width - spacing * (barCount - 1)) / barCount)
    readonly property var levels: active ? CavaService.levels(barCount) : []
    // Levels as drawn: eased once per cava frame instead of a height
    // Behavior. A Behavior retargeted by every frame keeps an animation
    // running nonstop, which repaints the window at the output refresh rate
    // (240 Hz on a 240 Hz monitor) instead of cava's 60 fps.
    property var drawn: []
    // Share of the distance covered per frame: matches the previous 70 ms
    // OutQuad retargeted every 16.7 ms (1 - (1 - 16.7 / 70)^2 = 0.42).
    readonly property real easing: Config.animDuration > 0 ? 0.42 : 1
    onLevelsChanged: drawn = levels.length ? ease(drawn, levels, easing) : []

    // One frame of easing toward `target`; bars without a previous value
    // start at the target.
    function ease(prev, target, k) {
        const out = new Array(target.length);
        for (let i = 0; i < target.length; i++) {
            const p = prev && i < prev.length ? prev[i] : target[i];
            out[i] = k >= 1 ? target[i] : p + (target[i] - p) * k;
        }
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
