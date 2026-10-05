.pragma library

// Small presentation helpers shared by the settings UI.

// `c` with its alpha multiplied by `a` (palette roles stay roles: callers
// pass Colors.<role>).
function alpha(c, a) {
    if (c === undefined || c === null)
        return Qt.rgba(0, 0, 0, 0);
    return Qt.rgba(c.r, c.g, c.b, c.a * a);
}

// Linear mix of two colors, t in [0, 1].
function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
}

// "300 ms", "1.2 s", "12 px"; special values ({value, label}) win.
function formatValue(value, unit, special, tr) {
    for (var i = 0; special && i < special.length; i++) {
        if (special[i].value === value)
            return tr ? tr(special[i].label) : special[i].label;
    }
    var v = Math.round(value * 100) / 100;
    if (unit === "ms" && v >= 1000)
        return (Math.round(v / 100) / 10) + " s";
    return unit ? v + " " + unit : String(v);
}

// Heuristic monospace detection for font family names (Qt only lists
// family names to QML).
function looksMonospace(family) {
    return /mono|code|console|courier|terminal|fixed|hack\b|iosevka|menlo|consolas|inconsolata|fira ?code|jetbrains|cascadia|source code|ubuntu mono|dejavu sans mono|liberation mono|victor|cozette|terminus|monaspace|commit/i.test(family);
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// Snap `v` to `step` within [min, max].
function snap(v, min, max, step) {
    var s = step > 0 ? step : 1;
    return clamp(Math.round((v - min) / s) * s + min, min, max);
}

// Duck-typed access to objects of unknown type (Loader items: legacy
// panels, editors). The key is a variable so tooling does not demand a
// static type.
function setIfPresent(obj, key, value) {
    if (obj && key in obj) {
        obj[key] = value;
        return true;
    }
    return false;
}

function prop(obj, key) {
    return obj && key in obj ? obj[key] : undefined;
}

function invoke(obj, name, args) {
    if (obj && typeof obj[name] === "function")
        return obj[name].apply(obj, args || []);
    return undefined;
}
