.pragma library

// macOS-like dock magnification (tested in tests/panel-modules.test.cjs).

// Scale of an icon whose center is `distance` px from the pointer, for
// icons `cell` px apart: `maxScale` under the pointer, easing back to 1 at
// `spread` cells away (raised-cosine falloff, no hard edge).
function scaleAt(distance, cell, maxScale, spread) {
    var s = spread || 2.5;
    var reach = Math.max(1, cell * s);
    var d = Math.abs(distance);
    if (d >= reach || maxScale <= 1)
        return 1;
    return 1 + (maxScale - 1) * (Math.cos(Math.PI * d / reach) + 1) / 2;
}

// Running-indicator dots: at most 3; more windows collapse to 3.
function dotCount(windows) {
    return Math.max(0, Math.min(3, windows || 0));
}
