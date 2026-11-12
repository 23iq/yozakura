import QtQuick
import qs.modules.theme
import "ShadowBlur.js" as ShadowBlur

// Theme drop shadow of a rounded rectangle, analytic (shape_shadow.frag):
// one quad driven by uniforms, no capture, no blur pass and no texture, so
// it costs the same every frame however often the shape morphs or moves.
// Same look as ShadowCaster's captured MultiEffect shadow (Lighting.shadow*,
// MultiEffect's blur modelled by ShadowBlur.js; tests/shape-shadow.test.py
// compares the two).
//
// Shapes: a box (`box`, in the parent's coordinates) with per-corner
// `radii` (tl, tr, br, bl); with `fillet` > 0, two concave fillets of that
// size where the box meets the screen `edge` (the attached notch; the box
// includes them); with `inverted`, everything outside the box (a screen
// frame around its rounded hole: the quad covers the parent). `strength`
// scales the shadow like a translucent source's alpha scaled the captured
// one. With `holeClipped`, the shadow is cut to the rounded box `holeClip`
// (parent coordinates, corner radius `holeClipRadius`): the screen frame's
// hole when the frame is drawn in a window below (performance.splitFrame).
ShaderEffect {
    id: root

    property rect box: Qt.rect(0, 0, 0, 0)
    property vector4d radii: Qt.vector4d(0, 0, 0, 0)
    property real fillet: 0
    property string edge: "top"
    property bool inverted: false
    property real strength: 1
    property bool active: true
    property rect holeClip: Qt.rect(0, 0, 0, 0)
    property real holeClipRadius: 0
    property bool holeClipped: false

    readonly property var blurModel: ShadowBlur.weights(Lighting.shadowBlur)
    readonly property real spill: root.blurModel.reach + 2
    readonly property bool hasArea: root.box.width >= 1 && root.box.height >= 1
    readonly property color shadowColor: Lighting.shadowColor
    readonly property real coverage: Lighting.shadowOpacity * root.shadowColor.a * Math.max(0, Math.min(1, root.strength))

    // The quad: the box grown by the blur's reach and moved by the light
    x: root.inverted ? 0 : root.box.x - root.spill + Lighting.shadowXOffset
    y: root.inverted ? 0 : root.box.y - root.spill + Lighting.shadowYOffset
    width: root.inverted ? (root.parent ? root.parent.width : 0) : root.box.width + root.spill * 2
    height: root.inverted ? (root.parent ? root.parent.height : 0) : root.box.height + root.spill * 2
    visible: root.active && root.hasArea && root.coverage > 0 && root.width > 0 && root.height > 0

    // Uniforms (shape_shadow.frag)
    property vector2d itemSize: Qt.vector2d(root.width, root.height)
    // the shape, moved by the light, in the quad's coordinates
    property vector4d shapeBox: Qt.vector4d(root.box.x + Lighting.shadowXOffset - root.x, root.box.y + Lighting.shadowYOffset - root.y, root.box.width, root.box.height)
    property vector4d weights: Qt.vector4d(root.blurModel.w[0], root.blurModel.w[1], root.blurModel.w[2], root.blurModel.w[3])
    property real sharpWeight: root.blurModel.sharp
    property real filletSize: root.inverted ? 0 : Math.max(0, root.fillet)
    property real edgeIndex: Math.max(0, ["top", "bottom", "left", "right"].indexOf(root.edge))
    property real invertedFlag: root.inverted ? 1 : 0
    property vector4d color: Qt.vector4d(root.shadowColor.r * root.coverage, root.shadowColor.g * root.coverage, root.shadowColor.b * root.coverage, root.coverage)
    // the clip box in the quad's coordinates
    property vector4d clipBox: Qt.vector4d(root.holeClip.x - root.x, root.holeClip.y - root.y, root.holeClip.width, root.holeClip.height)
    property real clipRadius: Math.max(0, Math.min(root.holeClipRadius, root.holeClip.width / 2, root.holeClip.height / 2))
    property real clipFlag: root.holeClipped ? 1 : 0

    fragmentShader: Qt.resolvedUrl("shape_shadow.frag.qsb")
}
