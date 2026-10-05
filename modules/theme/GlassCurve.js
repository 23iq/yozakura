.pragma library

// Curated glass curve: what one master `amount` (0..1) means for every
// translucency knob. 0 = solid, 0.5 = tasteful frosted, 1 = very glassy.
//
// Each parameter is a piecewise-linear curve over STOPS plus:
//   neutral  value meaning "no glass" (solid surface / no blur effect)
//   kind     "scaled": a preset's own (designed) value is reproduced at its
//            reference amount and scaled along the curve elsewhere;
//            "added": an effect presets never had (tint, highlight, softer
//            shadows), added only above the reference so a preset keeps its
//            look at its own amount
//   min/max  clamp for the effective value (and for advanced overrides)
//   integer  rounded to an integer (Hyprland blur size / passes)

var STOPS = [0, 0.25, 0.5, 0.75, 1];

var PARAMS = {
    "opacity": {
        "kind": "scaled",
        "neutral": 1,
        "points": [1, 0.9, 0.82, 0.7, 0.55],
        "min": 0.2,
        "max": 1
    },
    "blurSize": {
        "kind": "scaled",
        "neutral": 0,
        "points": [0, 4, 8, 11, 16],
        "min": 0,
        "max": 40,
        "integer": true
    },
    "blurPasses": {
        "kind": "scaled",
        "neutral": 1,
        "points": [1, 2, 3, 3, 4],
        "min": 1,
        "max": 8,
        "integer": true
    },
    "vibrancy": {
        "kind": "scaled",
        "neutral": 0,
        "points": [0, 0.08, 0.17, 0.25, 0.35],
        "min": 0,
        "max": 1
    },
    "noise": {
        "kind": "scaled",
        "neutral": 0,
        "points": [0, 0.008, 0.015, 0.02, 0.03],
        "min": 0,
        "max": 0.2
    },
    "contrast": {
        "kind": "scaled",
        "neutral": 1,
        "points": [1, 1.02, 1.05, 1.1, 1.15],
        "min": 0.5,
        "max": 2
    },
    // Dark themes dim the blurred backdrop (light text stays readable),
    // light themes brighten it.
    "brightness": {
        "kind": "scaled",
        "neutral": 1,
        "points": [1, 0.97, 0.92, 0.88, 0.84],
        "lightPoints": [1, 1.02, 1.05, 1.08, 1.12],
        "min": 0.5,
        "max": 2
    },
    "tintStrength": {
        "kind": "added",
        "neutral": 0,
        "points": [0, 0.03, 0.06, 0.09, 0.14],
        "min": 0,
        "max": 0.6
    },
    "borderHighlight": {
        "kind": "added",
        "neutral": 0,
        "points": [0, 0.06, 0.12, 0.18, 0.26],
        "min": 0,
        "max": 1
    },
    "shadowSoftness": {
        "kind": "added",
        "neutral": 0,
        "points": [0, 0.2, 0.45, 0.7, 1],
        "min": 0,
        "max": 1
    }
};

var NAMES = Object.keys(PARAMS);

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function spec(name) {
    return PARAMS[name] || null;
}

function points(name, light) {
    const p = PARAMS[name];
    return (light && p.lightPoints) ? p.lightPoints : p.points;
}

// Curve value of `name` at `amount` (clamped to 0..1).
function at(name, amount, light) {
    const pts = points(name, light);
    const a = clamp(Number(amount) || 0, 0, 1);
    for (let i = 1; i < STOPS.length; i++) {
        if (a <= STOPS[i]) {
            const t = (a - STOPS[i - 1]) / (STOPS[i] - STOPS[i - 1]);
            return pts[i - 1] + (pts[i] - pts[i - 1]) * t;
        }
    }
    return pts[pts.length - 1];
}

// Amount at which a monotonic curve reaches `value` (first match).
function invert(name, value, light) {
    const pts = points(name, light);
    const dec = pts[pts.length - 1] < pts[0];
    const v = dec ? clamp(value, pts[pts.length - 1], pts[0]) : clamp(value, pts[0], pts[pts.length - 1]);
    for (let i = 1; i < STOPS.length; i++) {
        const lo = pts[i - 1], hi = pts[i];
        const inside = dec ? (v <= lo && v >= hi) : (v >= lo && v <= hi);
        if (inside) {
            if (hi === lo)
                return STOPS[i - 1];
            return STOPS[i - 1] + (STOPS[i] - STOPS[i - 1]) * (v - lo) / (hi - lo);
        }
    }
    return dec ? 1 : 0;
}

function finish(name, v) {
    const p = PARAMS[name];
    const c = clamp(v, p.min, p.max);
    return p.integer ? Math.round(c) : c;
}
