import QtQuick
import qs.modules.components.kit

// Per-day usage (tokens per day, oldest first, today last) as the kit
// Sparkline, scaled to the busiest day.
Sparkline {
    id: root

    // Raw per-day values; the chart draws them relative to the peak.
    property var series: []
    readonly property real peak: Math.max.apply(null, [1].concat(root.series || []))

    values: (root.series || []).map(v => (v || 0) / root.peak)
    implicitWidth: Space.controlL
    implicitHeight: Space.l
}
