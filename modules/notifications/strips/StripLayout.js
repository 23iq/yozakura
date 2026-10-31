.pragma library

// Pure layout of the "strips" notification presentation (tanzaku: narrow
// strips hanging on a thread from a screen edge). Which edge, which groups
// hang and how many hide behind the "+N" knot, the per-strip thread length
// and the frame of one strip (thread, body, pivot) for every edge.
// Unit tested in tests/strips-layout.test.cjs; used by StripsView.qml,
// Strip.qml and StripBody.qml.

var EDGES = ["auto", "top", "bottom", "left", "right"];
var MATERIALS = ["plain", "paper", "washi"];

// Thread lengths cycle through these fractions of the thread step, picked
// by the strip's key, so a strip keeps its length while others come and go
// and the row reads as a loose, hand-hung rhythm instead of a ruler.
var RHYTHM = [0, 0.55, 0.2, 0.85, 0.4, 0.7, 0.1];

// Opacity of the palette role washed over a strip's paper.
var WASH = 0.18;

function oneOf(value, list, fallback) {
    return list.indexOf(value) !== -1 ? value : fallback;
}

// "auto" hangs from the top edge; a bar on the top edge is cleared by the
// view's insets, so the strips hang right under it.
function resolveEdge(edge) {
    var e = oneOf(edge, EDGES, "auto");
    return e === "auto" ? "top" : e;
}

// Strips on the top/bottom edge form a row and hang vertically; on a side
// edge they form a column and lie horizontally, like tags.
function isRow(edge) {
    return edge === "top" || edge === "bottom";
}

function hash(key) {
    var s = String(key || ""), h = 0;
    for (var i = 0; i < s.length; i++)
        h = (h * 31 + s.charCodeAt(i)) | 0;
    return Math.abs(h);
}

function threadLength(key, base, step) {
    return Math.round(base + RHYTHM[hash(key) % RHYTHM.length] * step);
}

// Which group keys hang (newest first, at most `max`) and how many more
// wait behind the knot.
function slots(keys, max) {
    var list = (keys || []).slice();
    var limit = Math.max(1, Number(max) || 1);
    return {
        "keys": list.slice(0, limit),
        "overflow": Math.max(0, list.length - limit)
    };
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

// Frame of one strip inside its slot. `o`: {thread, long, short, cardW,
// cardH, open (0 strip .. 1 card)}. The body is a long narrow strip that
// morphs into the card; the thread runs from the edge (the pivot the strip
// swings around) to the body's hole.
// -> {w, h, pivot{x,y}, thread{x,y,w,h}, body{x,y,w,h}, textRotation}
function frame(edge, o) {
    var t = Math.max(0, o.thread || 0);
    var open = Math.max(0, Math.min(1, o.open || 0));
    var row = isRow(edge);
    // Along the hang axis (away from the edge) and across it
    var along = lerp(o.long, row ? o.cardH : o.cardW, open);
    var across = lerp(o.short, row ? o.cardW : o.cardH, open);
    var f = {
        "w": row ? across : t + along,
        "h": row ? t + along : across
    };
    if (edge === "bottom") {
        f.body = { "x": 0, "y": 0, "w": across, "h": along };
        f.thread = { "x": across / 2, "y": along, "w": 0, "h": t };
        f.pivot = { "x": across / 2, "y": f.h };
        f.textRotation = 270;
    } else if (edge === "left") {
        f.body = { "x": t, "y": 0, "w": along, "h": across };
        f.thread = { "x": 0, "y": across / 2, "w": t, "h": 0 };
        f.pivot = { "x": 0, "y": across / 2 };
        f.textRotation = 0;
    } else if (edge === "right") {
        f.body = { "x": 0, "y": 0, "w": along, "h": across };
        f.thread = { "x": along, "y": across / 2, "w": t, "h": 0 };
        f.pivot = { "x": f.w, "y": across / 2 };
        f.textRotation = 0;
    } else {
        f.body = { "x": 0, "y": t, "w": across, "h": along };
        f.thread = { "x": across / 2, "y": 0, "w": 0, "h": t };
        f.pivot = { "x": across / 2, "y": 0 };
        f.textRotation = 90;
    }
    return f;
}

// Inside a folded strip of w x h: the punched hole the thread ends in (next
// to the edge), then the sender's art, then the text lane running away from
// the edge. `o`: {hole (zone of the hole), art (art size), pad}. Points are
// centres; the lane is `length` long along the strip.
// -> {hole{x,y}, art{x,y}, lane{x, y, length}}
function lanes(edge, w, h, o) {
    var row = isRow(edge);
    var long = row ? h : w, mid = (row ? w : h) / 2;
    var holeAt = o.hole * 0.55;
    var artAt = o.hole + o.art / 2;
    var start = o.hole + o.art + o.pad;
    var length = Math.max(0, long - start - o.pad);
    var laneAt = start + length / 2;
    // Distances from the edge side -> coordinates
    var far = edge === "bottom" || edge === "right";
    function at(d) {
        var a = far ? long - d : d;
        return row ? { "x": mid, "y": a } : { "x": a, "y": mid };
    }
    var lane = at(laneAt);
    lane.length = length;
    return {
        "hole": at(holeAt),
        "art": at(artAt),
        "lane": lane
    };
}

// Unit vector pointing from the strip back to its edge (the way it flies
// off when dismissed or lifted, and drops in from).
function towardEdge(edge) {
    return {
        "top": { "x": 0, "y": -1 },
        "bottom": { "x": 0, "y": 1 },
        "left": { "x": -1, "y": 0 },
        "right": { "x": 1, "y": 0 }
    }[edge] || { "x": 0, "y": -1 };
}
