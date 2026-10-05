pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme
import "GlassModel.js" as Model
import "GlassContrast.js" as Contrast

// Effective glass values for the whole shell, from `theme.glass` (one master
// amount + advanced + per-surface overrides, see GlassModel.js). Consumers:
// StyledRect (opacity, tint, top-edge highlight), Shadow, LockGlass,
// KittyGenerator (terminal opacity), CompositorTomlWriter/CompositorConfig
// (Hyprland blur, window opacity, shell layer blur).
//
// Legibility: every glass surface keeps its text (the variant's itemColor)
// at WCAG AA (4.5:1) over ANY wallpaper - the opacity is clamped to the
// worst-case floor computed in GlassContrast.js.
QtObject {
    id: root

    readonly property var ctx: Model.context(Config.theme ? Config.theme.glass : null, Config.theme, Config.lightMode)
    readonly property bool enabled: ctx.enabled
    // Effective master amount (0 when glass is off).
    readonly property real amount: Model.surfaceAmount(ctx, "")
    // Amount at which the preset shows exactly its own values.
    readonly property real reference: ctx.reference
    // true while theme.glass.amount follows the preset (-1).
    readonly property bool followsPreset: ctx.native

    readonly property var surfaces: Model.SURFACES

    function color(spec) {
        const c = Config.resolveColor(spec);
        return (typeof c === "string") ? Qt.color(c) : c;
    }

    function floorFor(surface, text) {
        return Contrast.minOpacity(surface, text, Contrast.WCAG_AA);
    }

    function variantFloor(cfg) {
        if (!cfg || !cfg.gradient || cfg.gradient.length === 0)
            return 0;
        return floorFor(color(cfg.gradient[0][0]), color(cfg.itemColor));
    }

    // Minimum legible opacity per glass variant.
    readonly property var floors: {
        const out = {};
        for (const v in Model.GLASS_VARIANTS)
            out[v] = variantFloor(Styling.getStyledRectConfig(v));
        return out;
    }

    readonly property real terminalFloor: floorFor(Colors.background, Colors.overSurface)
    readonly property real lockFloor: floorFor(Colors.shadow, Colors.secondaryFixed)

    readonly property var glassConfig: Config.theme ? Config.theme.glass : null
    readonly property color tintColor: color((glassConfig && glassConfig.tintRole) || "primary")
    readonly property color highlightColor: color((glassConfig && glassConfig.highlightRole) || "overBackground")

    function surfaceAmount(surface) {
        return Model.surfaceAmount(ctx, surface || "");
    }

    function isGlassVariant(variant) {
        return Model.isGlassVariant(variant);
    }

    // Opacity of a StyledRect variant whose configured opacity is `design`.
    function variantOpacity(variant, design, surface) {
        return Model.variantOpacity(ctx, variant, design, surface || "", floors[variant]);
    }

    function tintStrength(variant, design, surface) {
        return Model.effect(ctx, "tintStrength", variant, design, surface || "");
    }

    function highlight(variant, design, surface) {
        return Model.effect(ctx, "borderHighlight", variant, design, surface || "");
    }

    // Lock screen black glass strength (LockGlass.strength is its design).
    function lockOpacity(design) {
        return Model.scaleOpacity(ctx, design, surfaceAmount("lockscreen"), lockFloor);
    }

    // Worst-case text contrast of a variant at an opacity (settings preview).
    function worstContrast(variant, opacity) {
        const cfg = Styling.getStyledRectConfig(variant);
        if (!cfg || !cfg.gradient || cfg.gradient.length === 0)
            return 21;
        return Contrast.worstContrast(color(cfg.gradient[0][0]), color(cfg.itemColor), opacity);
    }

    function describe(amount) {
        return Model.describe(amount);
    }

    readonly property real terminalOpacity: Model.terminalOpacity(ctx, Config.theme, terminalFloor)
    // Hyprland decoration values driven by the "windows" surface.
    readonly property var compositor: Model.compositor(ctx, Config.compositor || {})
    readonly property bool shellBlur: Model.shellBlur(ctx)
    readonly property real shadowScale: Model.shadowScale(ctx)
}
