.pragma library

// Indeterminate ProgressLine: one calm segment sweeping across the track.
// Pure geometry so it can be tested (tests/progress-motion.test.cjs).

// Share of the track the moving segment covers.
var SEGMENT = 0.3;
// One sweep lasts this many emphasis tokens (450 ms max -> 1.8 s).
var CYCLE_TOKENS = 4;

// Duration of one sweep from the Motion emphasis token; 0 = no motion.
function cycle(emphasisMs) {
    return emphasisMs > 0 ? Math.round(emphasisMs * CYCLE_TOKENS) : 0;
}

// The visible segment {x, width} at phase t (0..1) of a sweep over a track
// `width` wide: it enters from the left edge and leaves at the right one,
// clipped to the track. Without motion (`still`) it rests centered.
function segment(t, width, still) {
    var w = Math.max(0, width) * SEGMENT;
    if (still)
        return {
            x: (width - w) / 2,
            width: w
        };
    var p = Math.max(0, Math.min(1, t));
    var start = -w + p * (width + w);
    var left = Math.max(0, start);
    var right = Math.min(width, start + w);
    return {
        x: left,
        width: Math.max(0, right - left)
    };
}
