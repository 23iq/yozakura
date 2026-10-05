.pragma library

// Small, dependency-free color helpers shared by the app theme generators.
// Colors are passed around as "#rrggbb" / "#rrggbbaa" strings so this file can
// also be exercised outside of QML (e.g. with node) for testing.

function clamp01(x) {
    return x < 0 ? 0 : (x > 1 ? 1 : x);
}

// Accepts "#rgb", "#rrggbb", "#rrggbbaa" (CSS order) or a QML color string.
function parseHex(hex) {
    let h = String(hex).trim().replace("#", "");
    if (h.length === 3)
        h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    const r = parseInt(h.slice(0, 2), 16) / 255;
    const g = parseInt(h.slice(2, 4), 16) / 255;
    const b = parseInt(h.slice(4, 6), 16) / 255;
    const a = h.length >= 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
    return { r: r, g: g, b: b, a: a };
}

function byteHex(v) {
    const n = Math.round(clamp01(v) * 255);
    return (n < 16 ? "0" : "") + n.toString(16);
}

// Returns "#rrggbb" (alpha omitted when undefined or 1 and keepAlpha is false).
function toHex(c, keepAlpha) {
    let s = "#" + byteHex(c.r) + byteHex(c.g) + byteHex(c.b);
    if (keepAlpha && c.a !== undefined && c.a < 1)
        s += byteHex(c.a);
    return s;
}

// QML colors stringify as "#aarrggbb" when translucent; normalize to "#rrggbb".
function fromQml(color) {
    const s = String(color);
    if (s.length === 9)
        return "#" + s.slice(3);
    return s;
}

function srgbToLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function linearToSrgb(c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
}

function toOklab(c) {
    const r = srgbToLinear(c.r), g = srgbToLinear(c.g), b = srgbToLinear(c.b);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return {
        L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    };
}

function fromOklab(o) {
    const l = Math.pow(o.L + 0.3963377774 * o.a + 0.2158037573 * o.b, 3);
    const m = Math.pow(o.L - 0.1055613458 * o.a - 0.0638541728 * o.b, 3);
    const s = Math.pow(o.L - 0.0894841775 * o.a - 1.2914855480 * o.b, 3);
    return {
        r: clamp01(linearToSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s)),
        g: clamp01(linearToSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s)),
        b: clamp01(linearToSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)),
        a: 1
    };
}

// Lightness / chroma / hue (degrees) of a hex color.
function lch(hex) {
    const o = toOklab(parseHex(hex));
    let h = Math.atan2(o.b, o.a) * 180 / Math.PI;
    if (h < 0)
        h += 360;
    return { L: o.L, C: Math.sqrt(o.a * o.a + o.b * o.b), h: h };
}

function fromLch(L, C, h) {
    const rad = h * Math.PI / 180;
    return toHex(fromOklab({ L: L, a: C * Math.cos(rad), b: C * Math.sin(rad) }));
}

// Perceptual mix: t = 0 -> a, t = 1 -> b.
function mix(a, b, t) {
    const oa = toOklab(parseHex(a)), ob = toOklab(parseHex(b));
    return toHex(fromOklab({
        L: oa.L + (ob.L - oa.L) * t,
        a: oa.a + (ob.a - oa.a) * t,
        b: oa.b + (ob.b - oa.b) * t
    }));
}

function withAlpha(hex, alpha) {
    const c = parseHex(hex);
    c.a = alpha;
    return toHex(c, true);
}

// "r,g,b" with 0-255 channels.
function rgbTriplet(hex) {
    const c = parseHex(hex);
    return Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255);
}

function hueDistance(h1, h2) {
    const d = Math.abs(h1 - h2) % 360;
    return d > 180 ? 360 - d : d;
}

// Rotate the hue of `hex` towards `towardsHex` by `amount` (0..1), capped at
// `maxDegrees`, keeping lightness and chroma (like Material "harmonize").
function harmonize(hex, towardsHex, amount, maxDegrees) {
    const c = lch(hex), t = lch(towardsHex);
    let diff = t.h - c.h;
    if (diff > 180)
        diff -= 360;
    if (diff < -180)
        diff += 360;
    let rot = diff * amount;
    const cap = maxDegrees === undefined ? 15 : maxDegrees;
    if (rot > cap)
        rot = cap;
    if (rot < -cap)
        rot = -cap;
    return fromLch(c.L, c.C, (c.h + rot + 360) % 360);
}

// Interpolate along a ramp of [position, hex] anchors (positions ascending).
function ramp(anchors, x) {
    if (x <= anchors[0][0])
        return anchors[0][1];
    for (let i = 1; i < anchors.length; i++) {
        if (x <= anchors[i][0]) {
            const p0 = anchors[i - 1][0], p1 = anchors[i][0];
            const t = p1 === p0 ? 1 : (x - p0) / (p1 - p0);
            return mix(anchors[i - 1][1], anchors[i][1], t);
        }
    }
    return anchors[anchors.length - 1][1];
}

// Pick the entry of `candidates` ({name: hex}) closest to `hex`, comparing hue
// first (folder icons are saturated, Material primaries are often pastel).
function nearestByHue(hex, candidates, neutralName) {
    const c = lch(hex);
    // Very desaturated accents map to a neutral candidate.
    if (neutralName && c.C < 0.03)
        return neutralName;
    let best = "", bestScore = Infinity;
    for (const name in candidates) {
        const k = lch(candidates[name]);
        if (k.C < 0.03)
            continue;
        const dh = hueDistance(c.h, k.h) / 180;          // 0..1
        const dc = Math.abs(Math.min(c.C, 0.2) - Math.min(k.C, 0.2)) / 0.2;
        const dl = Math.abs(c.L - k.L);
        const score = dh * 3 + dc * 0.6 + dl * 0.4;
        if (score < bestScore) {
            bestScore = score;
            best = name;
        }
    }
    return best;
}

// Material roles exported to app generators (subset of Colors.qml).
var roleNames = [
    "background", "overBackground", "surface", "overSurface", "overSurfaceVariant",
    "surfaceVariant", "surfaceDim", "surfaceBright", "surfaceContainerLowest",
    "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh",
    "surfaceContainerHighest", "outline", "outlineVariant", "shadow", "scrim",
    "primary", "overPrimary", "primaryContainer", "overPrimaryContainer",
    "primaryFixed", "primaryFixedDim", "inversePrimary",
    "secondary", "overSecondary", "secondaryContainer", "overSecondaryContainer",
    "tertiary", "overTertiary", "tertiaryContainer", "overTertiaryContainer",
    "error", "overError", "errorContainer", "overErrorContainer",
    "inverseSurface", "inverseOnSurface", "sourceColor",
    "red", "green", "yellow", "blue", "magenta", "cyan", "white"
];

// Snapshot a Colors-like object into {role: "#rrggbb"}.
function palette(colors) {
    const p = {};
    for (let i = 0; i < roleNames.length; i++) {
        const v = colors[roleNames[i]];
        if (v !== undefined && v !== null)
            p[roleNames[i]] = fromQml(v.toString());
    }
    return p;
}

// Relative luminance check used to pick dark/light variants.
function isDark(hex) {
    return lch(hex).L < 0.6;
}

// In-gamut OKLCH -> hex: keeps L and h, reduces chroma until sRGB fits.
function fromLchGamut(L, C, h) {
    const rad = h * Math.PI / 180;
    const inGamut = c => {
        const o = { L: L, a: c * Math.cos(rad), b: c * Math.sin(rad) };
        const l = Math.pow(o.L + 0.3963377774 * o.a + 0.2158037573 * o.b, 3);
        const m = Math.pow(o.L - 0.1055613458 * o.a - 0.0638541728 * o.b, 3);
        const s = Math.pow(o.L - 0.0894841775 * o.a - 1.2914855480 * o.b, 3);
        const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
        const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
        const bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
        const e = 0.0005;
        return r >= -e && r <= 1 + e && g >= -e && g <= 1 + e && bl >= -e && bl <= 1 + e;
    };
    let lo = 0, hi = C;
    if (!inGamut(hi)) {
        for (let i = 0; i < 18; i++) {
            const mid = (lo + hi) / 2;
            if (inGamut(mid))
                lo = mid;
            else
                hi = mid;
        }
        C = lo;
    }
    return fromLch(L, C, h);
}

// Terminal (ANSI) accent colors, independent of the matugen scheme variant.
//
// matugen derives custom colors with the *selected* scheme, so e.g.
// scheme-content/fidelity keep the very light tone of #ffff00/#00ffff and
// yield white, scheme-expressive rotates hues (red becomes blue) and
// scheme-monochrome makes all of them white. Here every color keeps its
// canonical hue, gets a fixed OKLCH lightness/chroma that is readable on the
// background, and is rotated slightly (<= 12 deg) towards the primary hue so
// it harmonizes with the wallpaper. Canonical hues are >= 55 deg apart, so
// the six colors always stay distinct.
//
// accentHex: palette primary; dark: whether the background is dark.
// Returns {red, green, yellow, blue, magenta, cyan, lightRed, ...} as hex.
var ansiHues = { red: 25, yellow: 90, green: 145, cyan: 200, blue: 255, magenta: 330 };

function ansiColors(accentHex, dark) {
    const acc = lch(accentHex);
    // Low-chroma (grayscale) palettes get calmer terminal colors.
    const vivid = 0.75 + 0.25 * Math.min(1, acc.C / 0.08);
    const out = {};
    for (const name in ansiHues) {
        let h = ansiHues[name];
        if (acc.C >= 0.02) {
            let diff = acc.h - h;
            if (diff > 180)
                diff -= 360;
            if (diff < -180)
                diff += 360;
            // Yellow turns orange/olive quickly, so it rotates less.
            const cap = name === "yellow" ? 7 : 12;
            const rot = Math.max(-cap, Math.min(cap, diff * 0.5));
            h = (h + rot + 360) % 360;
        }
        // Yellow needs extra lightness to read as yellow rather than olive;
        // cyan is perceptually louder at equal chroma, so it gets less.
        const yl = name === "yellow" ? 1 : 0;
        const cv = name === "cyan" ? 0.82 : 1;
        let L, C, bL, bC;
        if (dark) {
            L = 0.76 + 0.07 * yl; C = 0.13 * vivid * cv;
            bL = 0.84 + 0.05 * yl; bC = 0.10 * vivid * cv;
        } else {
            L = 0.50 + 0.04 * yl; C = 0.14 * vivid * cv;
            bL = 0.58 + 0.04 * yl; bC = 0.13 * vivid * cv;
        }
        out[name] = fromLchGamut(L, C, h);
        out["light" + name[0].toUpperCase() + name.slice(1)] = fromLchGamut(bL, bC, h);
    }
    return out;
}
