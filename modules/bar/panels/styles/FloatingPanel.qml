import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// "floating": the full strip detached from the screen edge by the density
// padding on every side, with rounder corners; the theme shadow is cast by
// shell/PanelShadows. The frame never swallows it (not containable).
ClassicPanel {
    outerMargin: Metrics.padding
    sideMargin: Metrics.padding
    stripRadius: Look.radius("surface", implicitThickness)
}
