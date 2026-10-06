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
