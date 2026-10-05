pragma Singleton
import QtQuick
import qs.config

// Single source of truth for the bar/notch resting geometry. Everything that
// used to hardcode 36/40/44 derives from here, so `bar.compact` (and future
// density options) only change these few numbers.
//
// Compact keeps every module and its content at full size (legibility
// first: workspace kanji, clock, icons) and only trims the padding the
// islands tabs and the notch add around them: 44/40px -> 36px.
QtObject {
    readonly property bool compact: Config.bar && Config.bar.compact !== undefined ? Config.bar.compact : false

    // Thickness of one bar module pill (buttons, clock, workspaces...)
    readonly property int moduleSize: 36

    // Resting height of the "default" notch theme (hanging from the edge)
    readonly property int notchRestHeight: compact ? 36 : (Config.showBackground ? 44 : 40)

    // Resting height of the floating "island" notch theme
    readonly property int notchIslandHeight: moduleSize

    // Padding between an islands-style tab and its modules, so the tabs
    // match the notch's resting height exactly
    readonly property int islandPadding: Math.max(0, Math.floor((notchRestHeight - moduleSize) / 2))

    // Geometry scaling relative to the regular density
    readonly property real scale: moduleSize / 36

    // Glyphs follow the module size (gently: 18px at 36, 16px at 30) so a
    // future denser module size stays legible next to the unscaled text
    function iconSize(base) {
        return Math.max(8, Math.round(base * (0.4 + 0.6 * scale)));
    }

    // iconSize() for a module of `size` px (panels with their own module size)
    function iconFor(base, size) {
        return Math.max(8, Math.round(base * (0.4 + 0.6 * size / 36)));
    }
}
