import QtQuick
import qs.modules.components.kit

// Per-day usage (tokens per day, oldest first, today last) as the kit
// Sparkline, scaled to the busiest day.
Sparkline {
    id: root

    // Raw per-day values; the chart draws them relative to the peak.
    property var series: []
    readonly property real peak: Math.max.apply(null, [1].concat(root.series || []))
    readonly property var levels: (root.series || []).map(v => (v || 0) / root.peak)

    // The kit Sparkline is a sliding window that keeps its first sample off
    // the left edge; a copy of the oldest day fills that slot so every day
    // of the range stays on screen.
    values: root.levels.length > 1 ? [root.levels[0]].concat(root.levels) : root.levels
    implicitWidth: Space.controlL
    implicitHeight: Space.l
}
