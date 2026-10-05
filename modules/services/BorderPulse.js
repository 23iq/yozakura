.pragma library
.import "CompositorAppearance.js" as Appearance

// Pure helpers of the music-reactive active border (BorderPulse.qml):
// spectrum -> energy -> smoothed, quantized level -> border/glow colors.
// Node-tested (tests/border-pulse.test.cjs).

// Number of distinct levels sent to the compositor: a level change is the
// only thing that costs an IPC round-trip, so a coarse ladder keeps the
// effective rate well below the 30 Hz tick while still reading as a pulse.
var STEPS = 10;

// Beat energy of a cava frame (0..1 bars): bass-weighted, so kicks drive
// the pulse and hi-hats do not flicker it.
function energy(values) {
    if (!values || !values.length)
        return 0;
    var n = values.length;
    var sum = 0, wsum = 0;
    for (var i = 0; i < n; i++) {
        var w = 1 - i / n;
        w = w * w;
        var v = Number(values[i]) || 0;
        sum += Math.max(0, Math.min(1, v)) * w;
        wsum += w;
    }
    return wsum > 0 ? Math.min(1, sum / wsum * 1.6) : 0;
}

// Envelope follower: fast attack, slow release.
function follow(prev, target, attack, release) {
    var k = target > prev ? attack : release;
    return prev + (target - prev) * k;
}

function quantize(level, steps) {
    var s = steps || STEPS;
    return Math.max(0, Math.min(s, Math.round(level * s)));
}

// Alpha multiplier for a level: silence dims the border to (1 - 0.85 *
// intensity), a full beat restores it.
function factor(level, intensity) {
    var i = Math.max(0, Math.min(1, Number(intensity) || 0));
    var l = Math.max(0, Math.min(1, level));
    return 1 - i * 0.85 * (1 - l);
}

// "rgb(rrggbb)" / "rgba(rrggbbaa)" with its alpha multiplied by f.
function scaleColor(str, f) {
    var m = /^rgba?\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\)$/.exec(String(str).trim());
    if (!m)
        return str;
    var a = m[2] ? parseInt(m[2], 16) / 255 : 1;
    var hex = m[1];
    return Appearance.formatColor({
        "r": parseInt(hex.slice(0, 2), 16) / 255,
        "g": parseInt(hex.slice(2, 4), 16) / 255,
        "b": parseInt(hex.slice(4, 6), 16) / 255,
        "a": a * f
    });
}

// Border value (single color or {colors, angle} gradient) scaled by f.
function scaleBorder(value, f) {
    if (typeof value === "string")
        return scaleColor(value, f);
    if (value && value.colors) {
        var colors = [];
        for (var i = 0; i < value.colors.length; i++)
            colors.push(scaleColor(value.colors[i], f));
        return {
            "colors": colors,
            "angle": value.angle
        };
    }
    return value;
}

// hl.config() table for one pulse frame. base = {border, shadow} as built
// by CompositorAppearance (shadow "" = shadows off: only the border pulses).
// The border width is deliberately left alone: border_size is global and
// changing it reflows every tiled window.
function frame(base, level, intensity) {
    var f = factor(level, intensity);
    var t = {
        "general": {
            "col": {
                "active_border": scaleBorder(base.border, f)
            }
        }
    };
    if (base.shadow)
        t.decoration = {
            "shadow": {
                "color": scaleColor(base.shadow, f)
            }
        };
    return t;
}

function frameLua(base, level, intensity) {
    return "hl.config(" + Appearance.luaLiteral(frame(base, level, intensity)) + ")";
}
