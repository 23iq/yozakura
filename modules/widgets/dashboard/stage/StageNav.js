.pragma library

// Spatial focus moves of the stage home: from the focused control's rect,
// the nearest control in the arrow's direction. Rects: {x, y, w, h} in one
// coordinate space; dir: "left" | "right" | "up" | "down". A candidate must
// lie beyond the current one's centre in that direction; the score is the
// gap along the direction plus twice the offset across it (0 while the two
// overlap across), so a move keeps its row or column when it can.
// Returns the index in `rects`, or -1. Unit tested in
// tests/dashboard-stage-nav.test.cjs.

function _span(a0, a1, b0, b1) {
    if (b1 < a0)
        return a0 - b1;
    if (b0 > a1)
        return b0 - a1;
    return 0;
}

function pick(rects, from, dir) {
    var f = rects[from];
    if (!f)
        return -1;
    var horizontal = dir === "left" || dir === "right";
    var sign = dir === "right" || dir === "down" ? 1 : -1;
    var fc = horizontal ? f.x + f.w / 2 : f.y + f.h / 2;
    var best = -1;
    var bestScore = Infinity;
    for (var i = 0; i < rects.length; i++) {
        if (i === from)
            continue;
        var r = rects[i];
        var c = horizontal ? r.x + r.w / 2 : r.y + r.h / 2;
        if ((c - fc) * sign <= 1)
            continue;
        var near = horizontal ? (sign > 0 ? r.x - (f.x + f.w) : f.x - (r.x + r.w)) : (sign > 0 ? r.y - (f.y + f.h) : f.y - (r.y + r.h));
        var across = horizontal ? _span(f.y, f.y + f.h, r.y, r.y + r.h) : _span(f.x, f.x + f.w, r.x, r.x + r.w);
        // Ties across (a wide row under several tiles): the closer centre wins.
        var centre = horizontal ? Math.abs((r.y + r.h / 2) - (f.y + f.h / 2)) : Math.abs((r.x + r.w / 2) - (f.x + f.w / 2));
        var score = Math.max(0, near) + across * 2 + centre * 0.01;
        if (score < bestScore) {
            bestScore = score;
            best = i;
        }
    }
    return best;
}

// Arrow key -> direction name ("" for other keys).
function direction(key) {
    return ({
            "16777234": "left",
            "16777236": "right",
            "16777235": "up",
            "16777237": "down"
        })[String(key)] || "";
}
