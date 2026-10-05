import QtQuick
import qs.modules.components.surfaceeffects
import qs.config
import qs.modules.theme
import "SurfaceEffects.js" as Effects

// Ink surface effect: rice-paper grain (full strength on light surfaces, a
// faint chalky tooth on dark ones) and an uneven sumi wash along the edges,
// drawn in the text (ink) color. Static: no animation at all.
ShaderEffect {
    id: root

    // Host StyledRect (null in previews).
    property var surface: null
    property real strength: SurfaceFx.strength
    property var options: SurfaceFx.options
    property color inkColor: Colors.overBackground
    property bool lightPaper: Config.lightMode

    readonly property vector2d size: Qt.vector2d(width, height)
    // Rounded clip of the host (previews set `cornerRadius`).
    property real cornerRadius: 0
    readonly property vector4d radii: surface ? Qt.vector4d(surface.topLeftRadius, surface.topRightRadius, surface.bottomRightRadius, surface.bottomLeftRadius) : Qt.vector4d(cornerRadius, cornerRadius, cornerRadius, cornerRadius)
    readonly property vector4d ink: Qt.vector4d(inkColor.r, inkColor.g, inkColor.b, 1)
    readonly property real grain: options.grain
    readonly property real paper: lightPaper ? 1 : 0.4
    readonly property real seed: 0.37

    opacity: surface ? Effects.surfaceVisibility(surface.rectOpacity) : 1
    fragmentShader: "ink_paper.frag.qsb"
}
