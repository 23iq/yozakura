import QtQuick
import qs.modules.components.surfaceeffects

// Ink effect highlight: the fill of a highlight rect (selection, focus,
// active pill) painted as a brush stroke instead of a rounded rect. The host
// StyledRect turns its own color transparent and keeps its content on top.
BrushStroke {
    id: root

    property var surface: null
    property real strength: SurfaceFx.strength
    property color fillColor: surface ? surface.fillColor : "black"

    color: fillColor
    // Rougher with more intensity, but never so ragged the label loses its
    // backing: the edges only eat into the outer ~16% of the thickness.
    roughness: 0.55 + 0.45 * strength
    dryness: 0.35 + 0.5 * strength

    Component.onCompleted: seed = 1 + Math.random() * 40
}
