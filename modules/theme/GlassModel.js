.pragma library
.import "GlassCurve.js" as Curve

// The glass system (config `theme.glass`): resolves the master amount, the
// advanced overrides and the per-surface overrides into the effective values
// the shell applies (StyledRect opacity/tint/highlight, compositor blur and
// window opacity, kitty opacity, shell layer blur, shadow softness).
//
// Presets keep their exact look: a preset's own values (sr* opacities,
// compositor blur, terminal opacity) are what it shows at its *reference*
// amount, derived from those values (theme.glass.referenceAmount = -1) or
// pinned. `amount = -1` means "the preset's own amount" (= the reference).
// Away from the reference every designed value is scaled along the curve
// (GlassCurve.js), so the one slider makes any preset more or less glassy.
//
// Sentinel -1 = inherit/auto everywhere (amount, referenceAmount, advanced.*,
// surfaces.*.amount, surfaces.windows.*Opacity).

// StyledRect variants that are glass surfaces -> theme key of their config.
var GLASS_VARIANTS = {
    "bg": "srBg",
    "popup": "srPopup",
    "internalbg": "srInternalBg",
    "pane": "srPane",
    "common": "srCommon",
    "barbg": "srBarBg",
    "frame": "srFrame"
};

// Variants whose designed opacity defines a preset's reference amount.
var REFERENCE_VARIANTS = ["srBg", "srPopup", "srInternalBg", "srPane", "srCommon"];

var SURFACES = ["windows", "terminal", "popups", "bar", "notch", "dock", "sidebars", "lockscreen", "settings", "widgets"];

var EPS = 1e-4;

function isSet(v) {
    return typeof v === "number" && isFinite(v) && v >= 0;
}

function isGlassVariant(variant) {
    return Object.prototype.hasOwnProperty.call(GLASS_VARIANTS, variant);
}

function themeOpacity(theme, key) {
    const v = theme && theme[key] ? theme[key].opacity : undefined;
    return (typeof v === "number" && isFinite(v)) ? v : undefined;
}

// Amount whose curve opacity matches the preset's mean designed
// transparency (opaque variants count as 0, transparent-by-design ones are
// skipped, the terminal opacity counts when set).
function deriveReference(theme) {
    const list = [];
    for (let i = 0; i < REFERENCE_VARIANTS.length; i++) {
        const o = themeOpacity(theme, REFERENCE_VARIANTS[i]);
        if (o !== undefined && o > 0)
            list.push(1 - Math.min(o, 1));
    }
    const t = theme ? theme.terminalOpacity : undefined;
    if (isSet(t) && t > 0)
        list.push(1 - Math.min(t, 1));
    if (list.length === 0)
        return 0;
    let sum = 0;
    for (let j = 0; j < list.length; j++)
        sum += list[j];
    const amount = Curve.invert("opacity", 1 - sum / list.length, false);
    return Math.round(amount * 1000) / 1000;
}

function plainSurfaces(glass) {
    const out = {};
    const src = glass ? glass.surfaces : null;
    for (let i = 0; i < SURFACES.length; i++) {
        const s = src ? src[SURFACES[i]] : null;
        out[SURFACES[i]] = {
            "amount": s ? s.amount : -1,
            "activeOpacity": s ? s.activeOpacity : -1,
            "inactiveOpacity": s ? s.inactiveOpacity : -1
        };
    }
    return out;
}

function plainAdvanced(glass) {
    const out = {};
    const src = glass ? glass.advanced : null;
    for (let i = 0; i < Curve.NAMES.length; i++) {
        const n = Curve.NAMES[i];
        out[n] = src && isSet(src[n]) ? src[n] : -1;
    }
    return out;
}

// Snapshot of everything the resolvers need, as a plain object. Reading the
// config here (inside a QML binding) is what makes Glass.qml reactive.
function context(glass, theme, light) {
    const derived = deriveReference(theme);
    const ref = glass && isSet(glass.referenceAmount) ? Curve.clamp(glass.referenceAmount, 0, 1) : derived;
    const master = glass && isSet(glass.amount) ? Curve.clamp(glass.amount, 0, 1) : ref;
    return {
        "enabled": !glass || glass.enabled !== false,
        "reference": ref,
        "derivedReference": derived,
        "master": master,
        "native": !(glass && isSet(glass.amount)),
        "light": !!light,
        "advanced": plainAdvanced(glass),
        "surfaces": plainSurfaces(glass)
    };
}

// Effective master amount for a surface ("" = the master itself).
function surfaceAmount(ctx, surface) {
    if (!ctx.enabled)
        return 0;
    const s = surface ? ctx.surfaces[surface] : null;
    return s && isSet(s.amount) ? Curve.clamp(s.amount, 0, 1) : ctx.master;
}

// Effective value of curve parameter `name` at `amount`, given the preset's
// designed value (undefined when the preset has none).
function param(ctx, name, amount, design) {
    const p = Curve.spec(name);
    if (!ctx.enabled)
        return p.neutral;
    const override = ctx.advanced[name];
    if (isSet(override))
        return Curve.finish(name, override);
    const c = Curve.at(name, amount, ctx.light);
    const cr = Curve.at(name, ctx.reference, ctx.light);
    if (p.kind === "added") {
        const base = isSet(design) ? design : 0;
        return Curve.finish(name, base + Math.max(0, c - cr));
    }
    if (design === undefined || design === null || !isFinite(design))
        return Curve.finish(name, c);
    if (Math.abs(amount - ctx.reference) < EPS)
        return design;
    return Curve.finish(name, rescale(p, design, c, cr, Curve.at(name, 1, ctx.light), amount < ctx.reference));
}

// Moves a designed value along the curve: below the reference it shrinks
// proportionally towards the neutral (amount 0 = solid); above it, it
// travels to the curve's end so amount 1 is "very glassy" for every preset
// (a value already beyond the end just follows the curve's slope).
function rescale(p, design, c, cr, end, below) {
    const n = p.neutral;
    if (below)
        return Math.abs(cr - n) < EPS ? design : n + (design - n) * (c - n) / (cr - n);
    const onNeutralSide = (end - design) * (end - n) > 0;
    if (onNeutralSide && Math.abs(end - cr) >= EPS)
        return design + (c - cr) * (end - design) / (end - cr);
    return design + (c - cr);
}

// Opacity of a translucent surface whose preset opacity is `design`.
// `floor` = minimum opacity keeping text legible on any wallpaper
// (GlassContrast.minOpacity); glass never pushes a surface below it, unless
// the preset itself was designed below it (then never below the design).
function scaleOpacity(ctx, design, amount, floor) {
    if (!(typeof design === "number" && isFinite(design)) || design <= 0)
        return design;
    if (!ctx.enabled)
        return 1;
    const raw = param(ctx, "opacity", amount, design);
    const f = typeof floor === "number" && isFinite(floor) ? floor : 0;
    return Math.max(raw, Math.min(f, design));
}

function variantOpacity(ctx, variant, design, surface, floor) {
    if (!isGlassVariant(variant))
        return design;
    return scaleOpacity(ctx, design, surfaceAmount(ctx, surface), floor);
}

// Tint / top-edge highlight strength for a glass variant on a surface.
function effect(ctx, name, variant, design, surface) {
    if (!isGlassVariant(variant) || !(design > 0))
        return 0;
    return param(ctx, name, surfaceAmount(ctx, surface), 0);
}

// Kitty background opacity: theme.terminalOpacity when set, else srBg.
function terminalOpacity(ctx, theme, floor) {
    const t = theme ? theme.terminalOpacity : undefined;
    const design = isSet(t) ? Math.min(t, 1) : themeOpacity(theme, "srBg");
    return scaleOpacity(ctx, design === undefined ? 1 : design, surfaceAmount(ctx, "terminal"), floor);
}

// Multiplier for shadow blur/range (1 at the reference, softer above it).
function shadowScale(ctx) {
    return 1 + param(ctx, "shadowSoftness", ctx.master, 0);
}

function windowOpacity(ctx, key) {
    const v = ctx.surfaces.windows[key];
    if (!ctx.enabled || !isSet(v))
        return 1;
    return Curve.clamp(v, 0.3, 1);
}

// Compositor (Hyprland decoration) values driven by the "windows" surface.
// `c` is Config.compositor (designed blur values).
function compositor(ctx, c) {
    const a = surfaceAmount(ctx, "windows");
    const num = (v, d) => (typeof v === "number" && isFinite(v)) ? v : d;
    const size = param(ctx, "blurSize", a, num(c.blurSize, 4));
    return {
        "blur": {
            // A preset without blur gets it once the amount goes above its own.
            "enabled": ctx.enabled && size >= 1 && (c.blurEnabled !== false || a > ctx.reference + EPS),
            "size": Math.max(1, size),
            "passes": param(ctx, "blurPasses", a, num(c.blurPasses, 2)),
            "noise": param(ctx, "noise", a, num(c.blurNoise, 0)),
            "contrast": param(ctx, "contrast", a, num(c.blurContrast, 1)),
            "brightness": param(ctx, "brightness", a, num(c.blurBrightness, 1)),
            "vibrancy": param(ctx, "vibrancy", a, num(c.blurVibrancy, 0))
        },
        "activeOpacity": windowOpacity(ctx, "activeOpacity"),
        "inactiveOpacity": windowOpacity(ctx, "inactiveOpacity"),
        "shadowScale": shadowScale(ctx)
    };
}

// Compositor blur behind the shell's own layers (off only when glass is off).
function shellBlur(ctx) {
    return ctx.enabled;
}

// Human label for an amount (settings readout, CLI help).
function describe(amount) {
    if (amount < 0.05)
        return "solid";
    if (amount < 0.35)
        return "subtle";
    if (amount < 0.65)
        return "frosted";
    if (amount < 0.9)
        return "glassy";
    return "crystal";
}
