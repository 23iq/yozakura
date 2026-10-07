import QtQuick
import qs.config
import qs.modules.components.surfaceeffects
import qs.modules.theme

// A sumi-e brush stroke filling the item along its long axis (pressed head,
// ragged edges, dry tapered tail). Used by the ink effect's highlights and
// the "brush" workspace indicator. `seed` varies the stroke; changing it
// redraws it (animated with `reveal` when animations are on).
ShaderEffect {
    id: root

    property color color: "black"
    property real seed: 1
    property real roughness: 1
    property real dryness: 0.8
    property real reveal: 1

    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector4d inkColor: Qt.vector4d(color.r, color.g, color.b, color.a)

    fragmentShader: SurfaceFx.brushShader

    onSeedChanged: {
        if (Config.animDuration > 0 && visible)
            draw.restart();
    }

    NumberAnimation {
        id: draw
        target: root
        property: "reveal"
        from: 0.35
        to: 1
        duration: Math.max(1, Config.animDuration * 0.6)
        easing.type: Motion.morph.easing
    }
}
