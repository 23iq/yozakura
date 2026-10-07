import QtQuick
import qs.modules.components.surfaceeffects
import qs.config
import qs.modules.theme
import "SurfaceEffects.js" as Effects

// CRT surface effect: light static scanlines (aligned to screen rows, so
// they line up across bar, notch and popups and stay horizontal on vertical
// bars), a slight edge vignette and a soft phosphor bloom in the accent
// color. The only motion is an optional short flicker when the surface
// appears (theme.surfaceEffectOptions.flicker; none with animations off).
ShaderEffect {
    id: root

    // Host StyledRect (null in previews).
    property var surface: null
    property real strength: SurfaceFx.strength
    property var options: SurfaceFx.options
    property color glowColor: Colors.primary

    readonly property vector2d size: Qt.vector2d(width, height)
    // Rounded clip of the host (previews set `cornerRadius`).
    property real cornerRadius: 0
    readonly property vector4d radii: surface ? Qt.vector4d(surface.topLeftRadius, surface.topRightRadius, surface.bottomRightRadius, surface.bottomLeftRadius) : Qt.vector4d(cornerRadius, cornerRadius, cornerRadius, cornerRadius)
    property vector4d rowMap: Qt.vector4d(0, 1, 0, 0)
    readonly property vector4d glow: Qt.vector4d(glowColor.r, glowColor.g, glowColor.b, 1)
    readonly property real pitch: 3
    property real flash: 0
    readonly property real lift: Config.lightMode ? 0.25 : 1

    opacity: surface ? Effects.surfaceVisibility(surface.rectOpacity) : 1
    fragmentShader: "crt.frag.qsb"

    function updateRowMap() {
        const m = Effects.screenRowMap(mapToItem(null, 0, 0), mapToItem(null, 1, 0), mapToItem(null, 0, 1));
        rowMap = Qt.vector4d(m[0], m[1], m[2], 0);
    }

    function powerOn() {
        if (options.flicker && Config.animDuration > 0 && visible)
            flicker.restart();
    }

    onWidthChanged: updateRowMap()
    onHeightChanged: updateRowMap()
    onVisibleChanged: {
        updateRowMap();
        powerOn();
    }
    Component.onCompleted: {
        updateRowMap();
        powerOn();
    }

    SequentialAnimation {
        id: flicker
        NumberAnimation {
            target: root
            property: "flash"
            to: 1
            duration: Motion.emphasis.duration
        }
        NumberAnimation {
            target: root
            property: "flash"
            to: 0.25
            duration: Motion.emphasis.duration
        }
        NumberAnimation {
            target: root
            property: "flash"
            to: 0.7
            duration: Motion.emphasis.duration
        }
        NumberAnimation {
            target: root
            property: "flash"
            to: 0
            duration: Motion.emphasis.duration
            easing.type: Motion.emphasis.easing
        }
    }
}
