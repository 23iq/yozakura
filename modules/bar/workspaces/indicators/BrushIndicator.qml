import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components.surfaceeffects

// "brush": a sumi-e brush stroke (ragged edges, dry tail) instead of a
// pill. Each workspace gets its own stroke, drawn in when it changes.
BrushStroke {
    id: root

    property var indicator: null
    // A swipe: a little longer than the slot, thick enough to back the label.
    readonly property bool vertical: indicator ? indicator.vertical : false
    readonly property real overshoot: 2
    readonly property real inset: indicator ? Math.round(indicator.slotSize * 0.15) : 0

    x: vertical ? inset : -overshoot
    y: vertical ? -overshoot : inset
    width: indicator ? Math.max(0, vertical ? indicator.width - inset * 2 : indicator.width + overshoot * 2) : 0
    height: indicator ? Math.max(0, vertical ? indicator.height + overshoot * 2 : indicator.height - inset * 2) : 0
    color: Config.resolveColor(Styling.getStyledRectConfig("primary").gradient[0][0])
    seed: indicator ? 3 + indicator.workspaceId * 7.31 : 1
    roughness: 0.9
    dryness: 0.7
}
