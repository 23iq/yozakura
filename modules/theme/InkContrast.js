.pragma library

// The muted ink (kit Type.muted: captions, hints, section labels) at WCAG
// AA (>= 4.5:1) on every ground it is drawn on, in every visual language
// and in light and dark schemes. It starts from the outline role pulled
// 40 % toward the secondary ink (the quiet caption tone) and is pulled
// further, toward the secondary ink and then the text, only as far as the
// worst ground needs. The grounds: the solid surfaces of the shell and the
// language's settings card over the window's ambient wallpaper (kit Card
// over kit Ambient), which in the translucent languages (ink, glass) turns
// grey in a light scheme and costs the plain mix its contrast.
// Pure: colours are {r, g, b} in 0..1 (a QML color works);
// tests/kit-muted-contrast.test.cjs.

var AA = 4.5;
var START = 0.4;
var STEP = 0.05;

// kit Ambient's wash toward the theme background over the wallpaper, at
// `level` (how much of the wallpaper shows, Look.ambientStrength). A light
// theme washes more: a dark wallpaper under a light window otherwise turns
// the whole window mid grey.
function ambientWash(light, level) {
    return light ? 0.74 - 0.2 * level : 0.5 - 0.28 * level;
}

// The wallpaper as kit Ambient draws it (blurred, contrast -0.45,
// brightness -0.06), at its worst for the scheme: a black wallpaper under a
// light theme (lifted to 0.165) and a mid grey one under a dark theme
// (0.44; a dark scheme usually comes from a dark wallpaper, and a white one
// would ask the muted ink to become the text).
var WALL = { light: 0.165, dark: 0.44 };

function channel(v) {
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function luminance(c) {
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

function mix(a, b, t) {
    return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t };
}

// The settings card (Look.card: fill role, fillOpacity, ambient, shadow)
// over the ambient wallpaper; a translucent card also shows its own shadow
// (kit Card's RectangularShadow, solid under the box) through its fill.
// `p.card` is the colour of the card's fill role.
function cardGround(p, card, light) {
    var level = card && card.ambient !== undefined ? card.ambient : 0.5;
    var w = light ? WALL.light : WALL.dark;
    var under = mix(p.background, { r: w, g: w, b: w }, level);
    under = mix(under, p.background, ambientWash(light, level));
    under = mix(under, p.shadow || { r: 0, g: 0, b: 0 }, card && card.shadow ? card.shadow : 0);
    var op = card && card.fillOpacity !== undefined ? card.fillOpacity : 1;
    return mix(under, p.card || p.surface, op);
}

// Every ground the muted ink is checked against.
function grounds(p, card, light) {
    var out = [];
    var roles = ["background", "surface", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh"];
    for (var i = 0; i < roles.length; i++) {
        if (p[roles[i]])
            out.push(p[roles[i]]);
    }
    out.push(cardGround(p, card, light));
    return out;
}

function worst(ink, gs) {
    var m = Infinity;
    for (var i = 0; i < gs.length; i++)
        m = Math.min(m, contrast(ink, gs[i]));
    return m;
}

// The ink at pull `t`: 0..1 outline -> secondary ink, 1..2 secondary -> text.
function inkAt(p, t) {
    return t <= 1 ? mix(p.outline, p.overSurfaceVariant, t) : mix(p.overSurfaceVariant, p.overBackground, t - 1);
}

// The pull the muted ink needs (START when the plain mix already passes).
function mutedPull(p, card, light) {
    var gs = grounds(p, card, light);
    for (var t = START; t < 2; t += STEP) {
        if (worst(inkAt(p, t), gs) >= AA)
            return t;
    }
    return 2;
}

// p: {outline, overSurfaceVariant, overBackground, background, surface,
// surfaceContainerLow, surfaceContainer, surfaceContainerHigh, shadow, card}.
function mutedInk(p, card, light) {
    return inkAt(p, mutedPull(p, card, light));
}
