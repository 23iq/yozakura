.pragma library

// The screen frame's analytic shadow (PanelShadows) is everything outside
// its rounded hole. A side of thickness 0 (a fullscreen window hides it)
// draws no frame, so it must cast nothing: the hole runs `out` px past that
// screen edge instead of ending on it. Unit tested in
// tests/frame-shadow.test.cjs.

// hole {x, y, w, h}; t {left, top, right, bottom}; -> {x, y, w, h}
function openHole(hole, t, out) {
    var x0 = t.left > 0 ? hole.x : hole.x - out;
    var y0 = t.top > 0 ? hole.y : hole.y - out;
    var x1 = t.right > 0 ? hole.x + hole.w : hole.x + hole.w + out;
    var y1 = t.bottom > 0 ? hole.y + hole.h : hole.y + hole.h + out;
    return {
        "x": x0,
        "y": y0,
        "w": x1 - x0,
        "h": y1 - y0
    };
}
