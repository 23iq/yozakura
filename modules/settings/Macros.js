.pragma library
.import "CompositorGate.js" as CompositorGate

// Macro sliders of the Look page (MacroSlider.qml): one plain-language knob
// (calm <-> lively, airy <-> compact, ...) over several existing keys. A
// macro stores nothing: its position is derived from the current values
// (the point every key matches, else "Custom") and moving it writes that
// point's values through SettingsStore, so Discard undoes it like any edit.
// Pure, node-tested: tests/settings-macros.test.cjs.
//
// Macro: {id, low, high (i18n keys of the two ends), keys, points}; the
// schema entry ({type: "macro", macro: id}) carries label and description.
//   keys   [{key, compositor?, tolerance?, unset?}]
//          compositor: the CompositorGate spec of a compositor-only key
//          (skipped elsewhere: read and written only where it applies);
//          tolerance: a numeric value within it of a point's value matches;
//          unset: the "follow the preset" sentinel (-1): read as
//          ctx.effective(key) (e.g. the preset's own glass amount)
//   points [{label, values: {key: value}}], low end first; a point may
//          leave a key out ("any value", e.g. the amount while glass is off)

var MACROS = [
    {
        "id": "motion",
        "low": "prefs.macro.motion.low",
        "high": "prefs.macro.motion.high",
        "keys": [{ "key": "compositor.motionProfile" }, { "key": "compositor.motionDurationScale", "tolerance": 0.001 }],
        "points": [
            { "label": "prefs.macro.motion.still", "values": { "compositor.motionProfile": "off" } },
            { "label": "prefs.macro.motion.calm", "values": { "compositor.motionProfile": "gentle", "compositor.motionDurationScale": 1.25 } },
            { "label": "prefs.macro.motion.smooth", "values": { "compositor.motionProfile": "smooth", "compositor.motionDurationScale": 1 } },
            { "label": "prefs.macro.motion.sakura", "values": { "compositor.motionProfile": "sakura", "compositor.motionDurationScale": 1 } },
            { "label": "prefs.macro.motion.bouncy", "values": { "compositor.motionProfile": "springs", "compositor.motionDurationScale": 1 } },
            { "label": "prefs.macro.motion.lively", "values": { "compositor.motionProfile": "snappy", "compositor.motionDurationScale": 0.85 } }
        ]
    },
    {
        "id": "density",
        "low": "prefs.macro.density.low",
        "high": "prefs.macro.density.high",
        "keys": [{ "key": "theme.density" }, { "key": "compositor.gapsIn" }, { "key": "compositor.gapsOut", "compositor": ["hyprland", "mango"] }],
        "points": [
            { "label": "prefs.macro.density.airy", "values": { "theme.density": "roomy", "compositor.gapsIn": 6, "compositor.gapsOut": 12 } },
            { "label": "prefs.macro.density.roomy", "values": { "theme.density": "roomy", "compositor.gapsIn": 4, "compositor.gapsOut": 8 } },
            { "label": "prefs.macro.density.cozy", "values": { "theme.density": "cozy", "compositor.gapsIn": 2, "compositor.gapsOut": 4 } },
            { "label": "prefs.macro.density.compact", "values": { "theme.density": "compact", "compositor.gapsIn": 1, "compositor.gapsOut": 2 } },
            { "label": "prefs.macro.density.dense", "values": { "theme.density": "compact", "compositor.gapsIn": 0, "compositor.gapsOut": 0 } }
        ]
    },
    {
        "id": "roundness",
        "low": "prefs.macro.roundness.low",
        "high": "prefs.macro.roundness.high",
        "keys": [{ "key": "theme.roundness" }, { "key": "theme.enableCorners" }],
        "points": [
            { "label": "prefs.macro.roundness.square", "values": { "theme.roundness": 0, "theme.enableCorners": false } },
            { "label": "prefs.macro.roundness.crisp", "values": { "theme.roundness": 6, "theme.enableCorners": true } },
            { "label": "prefs.macro.roundness.soft", "values": { "theme.roundness": 11, "theme.enableCorners": true } },
            { "label": "prefs.macro.roundness.round", "values": { "theme.roundness": 16, "theme.enableCorners": true } },
            { "label": "prefs.macro.roundness.pill", "values": { "theme.roundness": 24, "theme.enableCorners": true } }
        ]
    },
    {
        "id": "depth",
        "low": "prefs.macro.depth.low",
        "high": "prefs.macro.depth.high",
        "keys": [{ "key": "theme.shadowOpacity", "tolerance": 0.001 }, { "key": "theme.lighting.strength" }],
        "points": [
            { "label": "prefs.macro.depth.flat", "values": { "theme.shadowOpacity": 0, "theme.lighting.strength": "subtle" } },
            { "label": "prefs.macro.depth.soft", "values": { "theme.shadowOpacity": 0.3, "theme.lighting.strength": "subtle" } },
            { "label": "prefs.macro.depth.normal", "values": { "theme.shadowOpacity": 0.5, "theme.lighting.strength": "normal" } },
            { "label": "prefs.macro.depth.deep", "values": { "theme.shadowOpacity": 0.7, "theme.lighting.strength": "dramatic" } },
            { "label": "prefs.macro.depth.deepest", "values": { "theme.shadowOpacity": 0.9, "theme.lighting.strength": "dramatic" } }
        ]
    },
    {
        "id": "glass",
        "low": "prefs.macro.glass.low",
        "high": "prefs.macro.glass.high",
        "keys": [{ "key": "theme.glass.enabled" }, { "key": "theme.glass.amount", "tolerance": 0.125, "unset": -1 }],
        "points": [
            { "label": "prefs.glass.level.solid", "values": { "theme.glass.enabled": false } },
            { "label": "prefs.glass.level.subtle", "values": { "theme.glass.enabled": true, "theme.glass.amount": 0.25 } },
            { "label": "prefs.glass.level.frosted", "values": { "theme.glass.enabled": true, "theme.glass.amount": 0.5 } },
            { "label": "prefs.glass.level.glassy", "values": { "theme.glass.enabled": true, "theme.glass.amount": 0.75 } },
            { "label": "prefs.glass.level.crystal", "values": { "theme.glass.enabled": true, "theme.glass.amount": 1 } }
        ]
    }
];

function byId(id) {
    for (var i = 0; i < MACROS.length; i++) {
        if (MACROS[i].id === id)
            return MACROS[i];
    }
    return null;
}

// Every key a macro may write (the audit / tests).
function allKeys(macro) {
    return macro.keys.map(function (k) {
        return k.key;
    });
}

// The keys that apply on `compositor` (ctx.compositor).
function activeKeys(macro, ctx) {
    var name = ctx && ctx.compositor;
    return macro.keys.filter(function (k) {
        return CompositorGate.allows(k.compositor, name);
    });
}

function read(spec, ctx) {
    var v = ctx.get(spec.key);
    if (spec.unset !== undefined && v === spec.unset && ctx.effective)
        return ctx.effective(spec.key);
    return v;
}

function same(spec, a, b) {
    if (typeof a === "number" && typeof b === "number")
        return Math.abs(a - b) <= (spec.tolerance || 1e-9);
    return a === b;
}

// Does the live config sit on point `p`? Keys the point leaves out match
// anything; keys that do not apply here are ignored.
function matches(macro, p, ctx) {
    var point = macro.points[p];
    return activeKeys(macro, ctx).every(function (spec) {
        if (!(spec.key in point.values))
            return true;
        return same(spec, read(spec, ctx), point.values[spec.key]);
    });
}

// ctx = {get(key), compositor, effective(key)?}: the index of the point the
// config sits on, -1 = Custom (a key differs from every point).
function level(macro, ctx) {
    for (var i = 0; i < macro.points.length; i++) {
        if (matches(macro, i, ctx))
            return i;
    }
    return -1;
}

// Where the handle rests while Custom: the point most keys agree with (a
// numeric key counts by closeness), the earlier one on a tie.
function nearest(macro, ctx) {
    var at = level(macro, ctx);
    if (at >= 0)
        return at;
    var best = 0, bestScore = -1;
    var keys = activeKeys(macro, ctx);
    for (var i = 0; i < macro.points.length; i++) {
        var score = 0;
        var values = macro.points[i].values;
        keys.forEach(function (spec) {
            if (!(spec.key in values))
                return;
            var v = read(spec, ctx), want = values[spec.key];
            if (typeof v === "number" && typeof want === "number")
                score += 1 / (1 + Math.abs(v - want));
            else if (v === want)
                score += 1;
        });
        if (score > bestScore + 1e-9) {
            best = i;
            bestScore = score;
        }
    }
    return best;
}

// The writes that move the config to point `p`: [{key, value}], only keys
// that apply here and whose value differs.
function writes(macro, p, ctx) {
    var point = macro.points[p];
    if (!point)
        return [];
    var out = [];
    activeKeys(macro, ctx).forEach(function (spec) {
        if (!(spec.key in point.values))
            return;
        var want = point.values[spec.key];
        if (!same(spec, ctx.get(spec.key), want) || spec.unset !== undefined && ctx.get(spec.key) === spec.unset)
            out.push({ "key": spec.key, "value": want });
    });
    return out;
}
