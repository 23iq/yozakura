import QtQuick
import qs.modules.components.kit

// Progress of an install job on the kit ProgressLine: `percent` 0..100,
// < 0 (unknown) sweeps a segment across the track instead of filling.
ProgressLine {
    property int percent: -1

    value: Math.max(0, percent) / 100
    indeterminate: percent < 0
}
