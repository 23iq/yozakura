pragma ComponentBehavior: Bound
import QtQuick

// Frost on a surface (theme.weatherFx.frost, below 0 °C): ice creeping in
// from the four corners, colder (bigger, denser) the lower the temperature.
// `compact` (the bar) keeps it to the ends of the strip.
Item {
    id: root

    property real level: 0.5
    property real strength: 1
    property bool animate: false
    property int salt: 0
    property real radius: 0
    property bool compact: false

    readonly property real reach: {
        const base = root.compact ? Math.min(Math.min(root.width, root.height) * 0.8, Math.max(root.width, root.height) * 0.2) : Math.max(24, Math.min(150, Math.min(root.width, root.height) * 0.45));
        return Math.round(base * (0.7 + 0.3 * root.level));
    }

    Repeater {
        model: 4
        FrostCorner {
            required property int index
            corner: index
            width: root.reach
            height: root.reach
            x: index === 1 || index === 2 ? root.width - root.reach : 0
            y: index >= 2 ? root.height - root.reach : 0
            level: root.level
            strength: root.strength
            animate: root.animate
            salt: root.salt
            radius: root.radius
        }
    }
}
