.pragma library

// Pure geometry of the Windows stage (stages/WindowsStage.qml) and the
// layout cards (thumbs/TilingThumb.qml): the windows a tiling layout makes
// on a w x h area, with Hyprland's gaps (a border's outer edge sits
// `gapsOut` from the area's edge and 2 x `gapsIn` from its neighbour).
// Node-tested (tests/settings-windows-stage.test.cjs).

// The layouts drawn; anything else draws as dwindle.
var LAYOUTS = ["dwindle", "master", "scrolling"];

function clampNum(v, lo, hi) {
    var n = Number(v);
    if (!isFinite(n))
        n = lo;
    return Math.max(lo, Math.min(hi, n));
}

function rect(x, y, w, h) {
    return {
        "x": x,
        "y": y,
        "w": Math.max(0, w),
        "h": Math.max(0, h)
    };
}

// Splits [start, start + size) into `n` parts with `gap` between them.
function split(start, size, n, gap) {
    var each = (size - gap * (n - 1)) / n;
    var out = [];
    for (var i = 0; i < n; i++)
        out.push([start + i * (each + gap), each]);
    return out;
}

// The windows of `layout` on a w x h area: [{x, y, w, h}], the focused one
// first. dwindle: a spiral of four (left half, then the right half split
// down and across); master: one master and a stack of three; scrolling:
// columns of a fixed width, the last one running off the right edge.
function tiles(layout, w, h, gapsIn, gapsOut) {
    var gi = clampNum(gapsIn, 0, 1e4) * 2, go = clampNum(gapsOut, 0, 1e4);
    var x0 = go, y0 = go, iw = Math.max(0, w - go * 2), ih = Math.max(0, h - go * 2);
    if (layout === "master") {
        var mw = (iw - gi) * 0.56;
        var out = [rect(x0, y0, mw, ih)];
        split(y0, ih, 3, gi).forEach(function (p) {
            out.push(rect(x0 + mw + gi, p[0], iw - mw - gi, p[1]));
        });
        return out;
    }
    if (layout === "scrolling") {
        var col = (iw - gi) * 0.46;
        var cols = [];
        for (var i = 0; i < 3; i++)
            cols.push(rect(x0 + i * (col + gi), y0, col, ih));
        // the second column holds two windows, the focused one is the first
        var halves = split(y0, ih, 2, gi);
        return [cols[0], rect(cols[1].x, halves[0][0], col, halves[0][1]), rect(cols[1].x, halves[1][0], col, halves[1][1]), cols[2]];
    }
    var half = (iw - gi) / 2;
    var right = x0 + half + gi;
    var rows = split(y0, ih, 2, gi);
    var bottom = split(right, iw - half - gi, 2, gi);
    return [rect(x0, y0, half, ih), rect(right, rows[0][0], iw - half - gi, rows[0][1]), rect(bottom[0][0], rows[1][0], bottom[0][1], rows[1][1]), rect(bottom[1][0], rows[1][0], bottom[1][1], rows[1][1])];
}

// Drag handles of the stage: a value from where the drag started and how
// far the pointer moved (px on the stage = px on the screen).
// The gap between two windows is 2 x gapsIn: a horizontal drag of d px
// moves it by d / 2 (each side grows).
function gapFromDrag(start, dx) {
    return Math.round(clampNum(start + dx / 2, 0, 50));
}

// The screen-edge gap follows the pointer directly.
function edgeFromDrag(start, dx) {
    return Math.round(clampNum(start + dx, 0, 100));
}

// Rounding: dragging the corner knob inwards (dx, dy towards the window's
// middle) rounds it.
function roundingFromDrag(start, dx, dy) {
    return Math.round(clampNum(start + (dx + dy) / 2, 0, 40));
}

// The rounding the compositor draws: the shell's while it follows it.
function rounding(sync, own, shell) {
    return Math.round(clampNum(sync ? shell : own, 0, 40));
}
