import QtQuick
import QtQuick.Effects
import qs.config

// Theme drop shadow of one part of a larger item, drawn on its own (shadow
// only, no copy of the source), so it can sit beneath every other surface.
//
// Same look as `Shadow` (MultiEffect shadow, Config.theme.shadow*): the
// source region is captured into a texture of its own size, blurred with
// the same blur pyramid and weights the shadow uses (blur == shadowBlur,
// default blurMax), and every pixel is mapped to the shadow colour by its
// alpha (contrast -1 + brightness 0.5 turn premultiplied rgb into alpha,
// colorization paints it). Only this region is re-rendered when the source
// changes, instead of a full-screen layer.
//
// The caster must share the source's coordinate space (both children of
// the same full-size parent): it places itself at sourceRect, grown by the
// blur's spill.
Item {
    id: root

    // Item to cast from (rendered live into a texture, not hidden)
    property Item source: null
    // Region of `source` that holds its visuals (source coordinates)
    property rect sourceRect: Qt.rect(0, 0, 0, 0)
    property bool active: true

    readonly property bool hasArea: root.sourceRect.width >= 1 && root.sourceRect.height >= 1
    readonly property color shadowColor: Config.resolveColor(Config.theme.shadowColor)
    // MultiEffect's auto padding (blurMax 32): the blur spills this far
    readonly property int spill: 32

    visible: root.active && root.hasArea && root.source !== null && Config.theme.shadowOpacity > 0
    x: root.sourceRect.x + Config.theme.shadowXOffset - root.spill
    y: root.sourceRect.y + Config.theme.shadowYOffset - root.spill
    width: root.sourceRect.width + root.spill * 2
    height: root.sourceRect.height + root.spill * 2

    // The finished shadow is kept in a texture: per frame it costs one
    // textured quad, the blur only runs when the source region changes.
    layer.enabled: root.visible

    ShaderEffectSource {
        id: capture
        x: root.spill
        y: root.spill
        width: root.sourceRect.width
        height: root.sourceRect.height
        sourceItem: root.visible ? root.source : null
        sourceRect: root.sourceRect
        hideSource: false
        live: true
        visible: false
    }

    MultiEffect {
        // Sized from the capture, not the parent: MultiEffect reads its
        // source's size when its own geometry changes, so the source must
        // be resized first
        x: capture.x
        y: capture.y
        width: capture.width
        height: capture.height
        source: capture
        visible: root.visible
        blurEnabled: true
        blur: Config.theme.shadowBlur
        contrast: -1
        brightness: 0.5
        colorization: 1
        colorizationColor: Qt.rgba(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b, 1)
        opacity: Config.theme.shadowOpacity * root.shadowColor.a
    }
}
