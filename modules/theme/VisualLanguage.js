.pragma library

// Visual language (theme.language): how surface roles are drawn on top of
// the theme's sr* variants. The variants keep their colors; the language
// decides whether a role is a filled box, a ghost or a soft tint.
//   ink      one surface per window, no boxes inside it: containers are
//            invisible (grouping by spacing), buttons are ghosts, the accent
//            is a soft tint with an accent-colored glyph instead of a fill
//   glass    translucent inner cards with a hairline edge
//   tiles    solid, flat inner tiles with tight corners
//   classic  the variants exactly as configured
// Unit tested in tests/visual-language.test.cjs.

var LANGUAGES = ["ink", "glass", "tiles", "classic"];
var DEFAULT = "ink";

// Roles drawn inside a surface (never the surface itself: bg, popup, barbg,
// frame, transparent stay as configured in every language).
var CONTAINERS = { "pane": true, "internalbg": true };
var GHOSTS = { "common": true };
var HOVERS = { "focus": true };
var ACCENTS = {
    "primary": "primary", "overprimary": "primary", "primaryfocus": "primary",
    "secondary": "secondary", "oversecondary": "secondary", "secondaryfocus": "secondary",
    "tertiary": "tertiary", "overtertiary": "tertiary", "tertiaryfocus": "tertiary",
    "error": "error", "overerror": "error", "errorfocus": "error"
};

function normalize(lang) {
    return LANGUAGES.indexOf(lang) >= 0 ? lang : DEFAULT;
}

function copy(cfg) {
    var out = {};
    for (var k in cfg)
        out[k] = cfg[k];
    return out;
}

function withBorder(cfg, width) {
    var b = cfg.border && cfg.border.length ? cfg.border[0] : "surfaceBright";
    return [b, width];
}

// cfg: the variant's sr* config. Returns the config to draw with (a copy
// when anything changes, the same object otherwise).
function apply(lang, variant, cfg) {
    if (!cfg)
        return cfg;
    var l = normalize(lang);
    if (l === "classic")
        return cfg;
    var out;
    if (l === "ink") {
        if (CONTAINERS[variant] || GHOSTS[variant]) {
            out = copy(cfg);
            out.opacity = 0;
            out.border = withBorder(cfg, 0);
            return out;
        }
        if (HOVERS[variant]) {
            out = copy(cfg);
            out.opacity = Math.min(cfg.opacity === undefined ? 1 : cfg.opacity, 0.55);
            out.border = withBorder(cfg, 0);
            return out;
        }
        if (ACCENTS[variant]) {
            var role = ACCENTS[variant];
            out = copy(cfg);
            out.gradient = [[role, 0.0]];
            out.gradientType = "linear";
            out.opacity = variant.indexOf("focus") > 0 ? 0.26 : 0.16;
            out.itemColor = role;
            out.border = withBorder(cfg, 0);
            return out;
        }
        return cfg;
    }
    if (l === "glass") {
        if (CONTAINERS[variant] || GHOSTS[variant]) {
            out = copy(cfg);
            out.opacity = Math.min(cfg.opacity === undefined ? 1 : cfg.opacity, 0.35);
            out.border = withBorder(cfg, 1);
            return out;
        }
        return cfg;
    }
    // tiles: flat, solid inner tiles
    if (CONTAINERS[variant] || GHOSTS[variant]) {
        out = copy(cfg);
        out.opacity = 1;
        out.border = withBorder(cfg, 0);
        return out;
    }
    return cfg;
}

// How the shared kit (modules/components/kit) draws in each language. Read
// through the kit's Look singleton; components never branch on the name.
// Colors are Colors.* role names, opacities 0..1, weights CSS-style.
//   group     the box of a Group: fill + opacity, outline / top highlight
//             (overBackground / white alpha), radius ("none" | "card" =
//             control radius + 4 | "small"), inner padding (Space key or
//             ""), `gap` between stacked groups and `inset` (Surface
//             padding) as Space keys, `divider`: Group.divider draws its
//             hairline above the group
//   dividers  whether Divider hairlines are drawn at all
//   control   the rest / hover box of IconButton and Chip (null: the
//             theme's "common" / "focus" variants as configured), `shape`
//             ("round" | "square"), label weights, `solidActive`: active
//             controls become a solid accent fill with the on-accent glyph
//   window    the background of an app window (settings): null keeps the
//             theme's "bg" surface; glass is a translucent frosted fill
var KIT = {
    "ink": {
        group: { fill: "", fillOpacity: 0, outline: 0, highlight: 0, radius: "none", padding: "", gap: "l", inset: "l", divider: true },
        dividers: true,
        control: { fill: "overBackground", rest: 0, hoverFill: "overBackground", hover: 0.08, edge: 0, shape: "round", weight: 400, activeWeight: 500, solidActive: false },
        float: null,
        window: null
    },
    "glass": {
        group: { fill: "surface", fillOpacity: 0.4, outline: 0.10, highlight: 0.2, radius: "card", padding: "m", gap: "m", inset: "m", divider: false },
        dividers: true,
        control: { fill: "overBackground", rest: 0.07, hoverFill: "overBackground", hover: 0.14, edge: 0.12, shape: "round", weight: 400, activeWeight: 500, solidActive: false },
        float: { fill: "surface", fillOpacity: 0.62, outline: 0.18, highlight: 0.28 },
        window: { fill: "surface", fillOpacity: 0.72 }
    },
    "tiles": {
        group: { fill: "surfaceContainer", fillOpacity: 1, outline: 0, highlight: 0, radius: "small", padding: "m", gap: "s", inset: "s", divider: false },
        dividers: false,
        control: { fill: "surfaceContainerHigh", rest: 1, hoverFill: "surfaceContainerHighest", hover: 1, edge: 0, shape: "square", weight: 500, activeWeight: 600, solidActive: true },
        float: { fill: "surfaceContainer", fillOpacity: 1, outline: 0, highlight: 0 },
        window: null
    },
    "classic": {
        group: { fill: "surfaceContainer", fillOpacity: 0.6, outline: 0, highlight: 0, radius: "card", padding: "m", gap: "m", inset: "l", divider: false },
        dividers: true,
        control: null,
        float: null,
        window: null
    }
};

function kit(lang) {
    return KIT[normalize(lang)];
}
