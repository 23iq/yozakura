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

// Decimal places of a step ("0.05" -> 2, 1e-7 -> 7).
function decimals(x) {
    var str = String(Math.abs(x));
    var e = str.match(/e-(\d+)$/);
    if (e)
        return Number(e[1]);
    var dot = str.indexOf(".");
    return dot === -1 ? 0 : str.length - dot - 1;
}

// Snap `v` to `step` within [min, max]; the result is rounded to the
// decimals of step / min so float noise (0.30000000000000004) never reaches
// the config files.
function snap(v, min, max, step) {
    var s = step > 0 ? step : 1;
    var r = clamp(Math.round((v - min) / s) * s + min, min, max);
    var d = Math.max(decimals(s), decimals(min));
    return d > 0 ? Number(r.toFixed(Math.min(d, 10))) : r;
}

function isSpecial(value, min, max, specials) {
    if (value >= min && value <= max)
        return false;
    return (specials || []).some(function (sp) {
        return Math.abs(sp.value - value) < 1e-9;
    });
}

// One step of `dir` (+1 / -1) from `value`. Special values outside
// [min, max] (-1 = auto) are one step beyond the range ends: stepping down
// from `min` lands on one, stepping back up from it returns to `min`.
function stepValue(value, dir, min, max, step, specials) {
    var sp = (specials || []).map(function (x) {
        return x.value;
    });
    if (isSpecial(value, min, max, specials)) {
        if (value < min)
            return dir > 0 ? min : value;
        return dir < 0 ? max : value;
    }
    var s = step > 0 ? step : 1;
    var raw = value + dir * s;
    if (raw < min - 1e-9) {
        var below = sp.filter(function (x) {
            return x < min;
        });
        if (below.length && value <= min + 1e-9)
            return Math.max.apply(null, below);
    } else if (raw > max + 1e-9) {
        var above = sp.filter(function (x) {
            return x > max;
        });
        if (above.length && value >= max - 1e-9)
            return Math.min.apply(null, above);
    }
    return snap(raw, min, max, s);
}

// A finite number from a config value (NaN / non-numeric -> fallback).
function finite(v, fallback) {
    var n = Number(v);
    return isFinite(n) && v !== null && v !== undefined && v !== "" ? n : fallback;
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
