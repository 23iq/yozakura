.pragma library

// Pure motion of a hanging strip: the damped pendulum sway on arrival (and
// the smaller nudge its neighbours get), the tilt while it is dragged, what
// a drag gesture means and how long it takes to leave. Durations derive
// from a Motion token passed in (0 = motion off = no sway at all).
// Unit tested in tests/strips-physics.test.cjs; used by Strip.qml.

var SWAY_SPAN = 4;        // sway lasts this many Motion.emphasis durations
var SWAY_MAX_MS = 2400;   // ...but never longer than this
var CYCLES = 2.5;         // swings in one sway
var DAMPING = 3.2;        // exponential decay over the sway
var ARRIVAL_DEG = 7;      // swing of a strip that just arrived
var MAX_TILT_DEG = 24;    // tilt limit while dragged

function swayDuration(emphasisMs) {
    var base = Number(emphasisMs) || 0;
    return base <= 0 ? 0 : Math.min(SWAY_MAX_MS, Math.round(base * SWAY_SPAN));
}

// Swing amplitude (degrees) of the strip `distance` slots away from the
// one that arrived (0 = itself): neighbours only feel a light nudge.
function amplitude(distance) {
    var d = Math.max(0, distance | 0);
    if (d > 2)
        return 0;
    return ARRIVAL_DEG / (1 + 3 * d);
}

// Angle (degrees) at progress p (0..1) of a sway: starts at rest (the drop
// hands over smoothly), swings, decays and lands exactly at rest.
function swayAngle(p, amp) {
    var t = Math.max(0, Math.min(1, Number(p) || 0));
    if (t >= 1 || !amp)
        return 0;
    return amp * Math.exp(-DAMPING * t) * Math.sin(2 * Math.PI * CYCLES * t) * (1 - t);
}

// Drag vector (dx, dy in pixels) split into `along` (away from the edge,
// > 0 = pulled down from the top edge) and `across`.
function project(edge, dx, dy) {
    switch (edge) {
    case "bottom":
        return { "along": -dy, "across": dx };
    case "left":
        return { "along": dx, "across": dy };
    case "right":
        return { "along": -dx, "across": dy };
    default:
        return { "along": dy, "across": dx };
    }
}

// What a released drag means: pulling the strip away from its edge opens
// it, flicking it back toward the edge or swiping it sideways dismisses it.
// -> "expand" | "dismiss" | "none"
function gesture(edge, dx, dy, threshold) {
    var th = Math.max(1, Number(threshold) || 1);
    var v = project(edge, dx, dy);
    if (v.along <= -th || Math.abs(v.across) >= th * 1.5)
        return "dismiss";
    if (v.along >= th)
        return "expand";
    return "none";
}

// Tilt (degrees, clockwise) of a strip of `radius` px (pivot to body
// centre) whose body is dragged `across` px sideways: it follows the
// pointer around its pivot, within a limit.
function dragTilt(edge, across, radius) {
    var r = Math.max(1, Number(radius) || 1);
    var deg = Math.atan2(Number(across) || 0, r) * 180 / Math.PI;
    deg = Math.max(-MAX_TILT_DEG, Math.min(MAX_TILT_DEG, deg));
    // A rightward drag swings a top strip counter-clockwise; the other
    // edges mirror it so the body always follows the pointer
    return (edge === "top" || edge === "right") ? -deg : deg;
}

// How long leaving takes: a flick flies off at once, a timeout lifts the
// strip away gently.
function exitDuration(kind, exitMs) {
    var base = Math.max(0, Number(exitMs) || 0);
    return kind === "lift" ? Math.round(base * 2) : base;
}
