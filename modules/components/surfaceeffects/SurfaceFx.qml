pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme
import "SurfaceEffects.js" as Effects

// The active surface effect (theme.surfaceEffect, registry SurfaceEffects.js)
// resolved for the whole shell. StyledRect asks it whether to load an
// overlay (`surfaceUrl`, surface roots only) or a highlight fill
// (`highlightUrl` + `highlights(variant)`); both are "" with "none", so the
// loaders stay inactive and nothing is created.
QtObject {
    id: root

    readonly property string effectId: {
        const id = Config.theme ? Config.theme.surfaceEffect : "";
        return Effects.isValid(id) ? id : Effects.DEFAULT_ID;
    }
    readonly property var effect: Effects.get(effectId)
    readonly property bool active: effectId !== Effects.DEFAULT_ID
    readonly property var options: Effects.options(Config.theme ? Config.theme.surfaceEffectOptions : null)

    readonly property string surfaceUrl: effect.surface ? Qt.resolvedUrl(effect.surface) : ""
    readonly property string highlightUrl: effect.highlight && Effects.highlights(effectId, options, effect.highlightVariants[0]) ? Qt.resolvedUrl(effect.highlight) : ""

    // Shader URLs resolved here: a component deriving from BrushStroke in
    // another directory would resolve a relative path against its own.
    readonly property url brushShader: Qt.resolvedUrl("brush.frag.qsb")

    // Palette the legibility clamp is computed against (text on surfaces).
    readonly property var palette: ({
            "surface": Colors.background,
            "text": Colors.overBackground,
            "accent": Colors.primary
        })

    // Intensity actually drawn: the option, lowered when needed so surface
    // text stays at WCAG AA (SurfaceEffects.safeStrength).
    readonly property real strength: strengthFor(effectId, options.intensity)

    function strengthFor(id, intensity) {
        return Effects.safeStrength(id, intensity, palette);
    }

    function urlFor(id) {
        const e = Effects.get(id);
        return e.surface ? Qt.resolvedUrl(e.surface) : "";
    }

    function highlightUrlFor(id) {
        const e = Effects.get(id);
        return e.highlight && Effects.highlights(id, options, e.highlightVariants[0]) ? Qt.resolvedUrl(e.highlight) : "";
    }

    function appliesTo(surface) {
        return surfaceUrl !== "" && Effects.appliesTo(surface);
    }

    function highlights(variant) {
        return highlightUrl !== "" && effect.highlightVariants.indexOf(variant) !== -1;
    }
}
