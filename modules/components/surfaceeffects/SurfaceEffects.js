.pragma library
.import "../../theme/GlassContrast.js" as Contrast

// Surface effects registry (theme.surfaceEffect + theme.surfaceEffectOptions).
//
// A surface effect is a signature texture drawn over the background of the
// shell's own surfaces (StyledRect roots with a `glassSurface`: bar, notch,
// launcher/dashboard, popups, dock, sidebars, settings, desktop widgets),
// under their content. App windows are never touched. It can also replace
// the fill of highlight rects (selection, focus, active pills) with its own
// shape. With "none" no loader is active: zero cost.
//
// Entry fields:
//   id          config value
//   label       human readable name
//   surface     component (file in this directory) drawn over a surface
//               background; "" = none. It gets `surface` (the host
//               StyledRect, may be null in previews), `strength` (0..1,
//               already legibility-clamped) and `options` (resolved).
//   highlight   component replacing the fill of highlight rects ("" = none);
//               it gets `fillColor`, `seed` and `strength`
//   highlightVariants   StyledRect variants treated as highlights
//   highlightOption     boolean option that turns the highlights on/off
//   options     option keys the effect reads (settings show only these)
//   overlay     worst-case overlays at strength 1, used to keep text at
//               WCAG AA: [{ "toward": "black"|"white"|"text"|"accent", "alpha": a }]
//               (a pixel at most mixes that far toward that color)
//
// To add an effect: one component file here + one entry below; validation,
// the catalog and the settings cards pick it up.

var DEFAULT_ID = "none";

// Shared options (theme.surfaceEffectOptions); each effect uses a subset.
var OPTIONS = {
    "intensity": { "default": 0.5, "min": 0, "max": 1 },
    "flicker": { "default": true },
    "grain": { "default": 0.6, "min": 0, "max": 1 },
    "brushHighlights": { "default": true }
};

// Shell surfaces an effect is drawn on (Glass.qml surface ids of StyledRect
// roots). Windows / terminal / lockscreen are not shell surfaces here.
var SURFACES = ["bar", "notch", "popups", "dock", "sidebars", "settings", "widgets"];

var EFFECTS = [
    {
        "id": "none",
        "label": "None",
        "surface": "",
        "highlight": "",
        "highlightVariants": [],
        "highlightOption": "",
        "options": [],
        "overlay": []
    },
    {
        "id": "crt",
        "label": "CRT",
        "surface": "CrtSurface.qml",
        "highlight": "",
        "highlightVariants": [],
        "highlightOption": "",
        "options": ["intensity", "flicker"],
        // scanlines + edge vignette darken, the phosphor bloom tints
        "overlay": [{ "toward": "black", "alpha": 0.33 }, { "toward": "accent", "alpha": 0.15 }]
    },
    {
        "id": "ink",
        "label": "Ink",
        "surface": "InkSurface.qml",
        "highlight": "InkHighlight.qml",
        "highlightVariants": ["primary", "primaryfocus", "focus"],
        "highlightOption": "brushHighlights",
        "options": ["intensity", "grain", "brushHighlights"],
        // paper grain specks and the sumi wash are drawn in the text color
        "overlay": [{ "toward": "text", "alpha": 0.24 }]
    }
];

function ids() {
    return EFFECTS.map(function (e) {
        return e.id;
    });
}

function isValid(id) {
    return ids().indexOf(id) !== -1;
}

function get(id) {
    for (var i = 0; i < EFFECTS.length; i++) {
        if (EFFECTS[i].id === id)
            return EFFECTS[i];
    }
    return EFFECTS[0];
}

function clampNumber(v, spec) {
    var n = Number(v);
    if (typeof v !== "number" || !isFinite(n))
        return spec["default"];
    return Math.max(spec.min, Math.min(spec.max, n));
}

// theme.surfaceEffectOptions with defaults and ranges applied.
function options(raw) {
    var src = raw || {};
    var out = {};
    for (var k in OPTIONS) {
        var spec = OPTIONS[k];
        if (typeof spec["default"] === "boolean")
            out[k] = typeof src[k] === "boolean" ? src[k] : spec["default"];
        else
            out[k] = clampNumber(src[k], spec);
    }
    return out;
}

function appliesTo(surface) {
    return SURFACES.indexOf(surface) !== -1;
}

function usesOption(id, key) {
    return get(id).options.indexOf(key) !== -1;
}

// Whether StyledRects of `variant` get the effect's highlight fill.
function highlights(id, opts, variant) {
    var e = get(id);
    if (!e.highlight || e.highlightVariants.indexOf(variant) === -1)
        return false;
    return !e.highlightOption || !!options(opts)[e.highlightOption];
}

function mixToward(surface, target, alpha) {
    return Contrast.over(target, surface, alpha);
}

// Lowest text contrast of an effect at `strength` (every overlay at its
// worst-case alpha). palette: {surface, text, accent} colors {r, g, b}.
function worstContrast(id, strength, palette) {
    var e = get(id);
    var lt = Contrast.luminance(palette.text);
    var worst = Contrast.ratio(lt, Contrast.luminance(palette.surface));
    for (var i = 0; i < e.overlay.length; i++) {
        var o = e.overlay[i];
        var target = o.toward === "black" ? Contrast.BLACK : o.toward === "white" ? Contrast.WHITE : o.toward === "text" ? palette.text : (palette.accent || palette.text);
        var mixed = mixToward(palette.surface, target, o.alpha * strength);
        worst = Math.min(worst, Contrast.ratio(lt, Contrast.luminance(mixed)));
    }
    return worst;
}

// Largest strength <= `wanted` that keeps text at WCAG AA (or, when the
// palette itself is below AA, never lowers its contrast by more than 3%).
function safeStrength(id, wanted, palette) {
    var w = Math.max(0, Math.min(1, Number(wanted) || 0));
    if (w === 0 || !palette || !palette.surface || !palette.text)
        return w;
    var base = worstContrast(id, 0, palette);
    var goal = Math.min(Contrast.WCAG_AA, base * 0.97);
    if (worstContrast(id, w, palette) >= goal)
        return w;
    var lo = 0, hi = w;
    for (var i = 0; i < 20; i++) {
        var mid = (lo + hi) / 2;
        if (worstContrast(id, mid, palette) >= goal)
            lo = mid;
        else
            hi = mid;
    }
    return Math.floor(lo * 1000) / 1000;
}

// How strongly an effect shows on a surface of opacity `surfaceOpacity`:
// fully on opaque/glass surfaces, fading out on (nearly) invisible ones.
function surfaceVisibility(surfaceOpacity) {
    var o = Number(surfaceOpacity);
    if (!isFinite(o))
        return 1;
    return Math.max(0, Math.min(1, o / 0.35));
}

// Screen-space scanline mapping of an item: [dY/dx, dY/dy, Y0] where Y is
// the screen row of local point (x, y). Points are {x, y} of the item's
// local (0,0), (1,0) and (0,1) mapped to the scene.
function screenRowMap(origin, unitX, unitY) {
    if (!origin || !unitX || !unitY)
        return [0, 1, 0];
    return [unitX.y - origin.y, unitY.y - origin.y, origin.y];
}
