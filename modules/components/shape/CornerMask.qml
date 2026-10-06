import QtQuick
import QtQuick.Effects
import qs.config
import qs.modules.theme

// Layer effect of a StyledRect with a non-round corner style: clips the
// rendered rect (content, gradients, surface effects) to the SDF shape of
// corner_mask.frag, paints the fill under it and the border over it.
// `shadow` draws the theme drop shadow around the masked shape.
Item {
    id: root

    // Set by the layer (layer.samplerName defaults to "source")
    property var source

    property real shapeStyle: 0
    property real cutSize: 10
    property real borderWidth: 0
    property vector4d radii: Qt.vector4d(0, 0, 0, 0)
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 0)
    property vector4d borderColor: Qt.vector4d(0, 0, 0, 0)
    property bool shadow: false
    // MultiEffect's default blurMax: blur 1.0 spreads this many pixels
    readonly property real blurMax: 32

    // The theme drop shadow (Shadow.qml values), analytic: a MultiEffect
    // downstream of the mask would resample the layer texture.
    Loader {
        anchors.fill: parent
        active: root.shadow
        sourceComponent: RectangularShadow {
            offset: Qt.vector2d(Config.theme.shadowXOffset, Config.theme.shadowYOffset)
            blur: Math.min(1, Config.theme.shadowBlur * Glass.shadowScale) * root.blurMax
            radius: Math.max(root.radii.x, root.radii.y, root.radii.z, root.radii.w)
            color: {
                const c = Qt.color(Config.resolveColor(Config.theme.shadowColor));
                return Qt.rgba(c.r, c.g, c.b, c.a * Config.theme.shadowOpacity);
            }
        }
    }

    ShaderEffect {
        id: mask
        anchors.fill: parent

        property var source: root.source
        property real shapeStyle: root.shapeStyle
        property real cutSize: root.cutSize
        property real borderWidth: root.borderWidth
        property vector2d shapeSize: Qt.vector2d(width, height)
        property vector4d radii: root.radii
        property vector4d fillColor: root.fillColor
        property vector4d borderColor: root.borderColor

        fragmentShader: Qt.resolvedUrl("corner_mask.frag.qsb")
    }
}
