.pragma library

// Keeps a grown notch off the bar's own modules when both share an edge.
// The resting notch stays where the user put it; once it shows more than
// that (hover, a panel, a notification, a live activity, a hosted view),
// its footprint along the edge is checked against the spans the bar's
// modules cover:
//   "edge"   no overlap (or nothing to avoid): stays on the edge;
//   "shift"  the free slot between bar groups holding its center is long
//            enough: it slides along the edge into that slot;
//   "drop"   otherwise it leaves the edge and hangs past the bar (below a
//            top bar, above a bottom one), growing away from the edge
//            instead of sideways over the bar.
// A side notch (left/right) is already laid out beside a bar on its edge
// (EdgeLayout.notchRect), so it never needs to move. A notch the pointer
// grew (`anchored`) never moves either: what the pointer is on stays under
// it (a dock-like bar parts around it instead, DockSplit.js). Positions are along
// the edge (x for top/bottom, y for left/right), in screen pixels.
// Unit tested in tests/notch-avoid.test.cjs.

var VERTICAL = { left: true, right: true };

// Spans [a, b] along the edge covered by bar modules. bar: { lo, hi (the
// bar's span), inset (frame + side margin before the content of a bar
// filling the edge), startReach, endReach (content from each end; 0 when
// the style packs everything in one run), center (a center group) }.
function occupied(bar) {
    if (!bar || !(bar.hi > bar.lo))
        return [];
    var s = Math.max(0, bar.startReach || 0);
    var e = Math.max(0, bar.endReach || 0);
    if (bar.center || (s <= 0 && e <= 0))
        return [[bar.lo, bar.hi]];
    var inset = Math.max(0, bar.inset || 0);
    var out = [];
    if (s > 0)
        out.push([bar.lo, Math.min(bar.hi, bar.lo + inset + s)]);
    if (e > 0)
        out.push([Math.max(bar.lo, bar.hi - inset - e), bar.hi]);
    return out;
}

function overlaps(spans, a, b) {
    for (var i = 0; i < spans.length; i++)
        if (spans[i][0] < b && spans[i][1] > a)
            return true;
    return false;
}

// Free slots of [0, total] around `spans`, in order
function freeSlots(total, spans) {
    var sorted = (spans || []).slice().sort(function (p, q) {
        return p[0] - q[0];
    });
    var out = [];
    var at = 0;
    for (var i = 0; i < sorted.length; i++) {
        if (sorted[i][0] > at)
            out.push([at, Math.min(total, sorted[i][0])]);
        at = Math.max(at, sorted[i][1]);
    }
    if (at < total)
        out.push([at, total]);
    return out;
}

// o: { pos, transient, occupied, total (edge length), start, length (the
// grown notch along the edge, where it would sit), barDepth (bar + its
// margins + frame from the screen edge), edgeGap (notch's own gap to the
// edge), gap (space left between bar and dropped notch), anchored (the
// pointer grew it: it stays where it is) }.
// Returns { mode, along, across } (across: px away from the edge).
function avoid(o) {
    var none = { mode: "edge", along: 0, across: 0 };
    if (!o || !o.transient || o.anchored || VERTICAL[o.pos] || !o.occupied || !o.occupied.length || !(o.length > 0))
        return none;
    var a = o.start;
    var b = o.start + o.length;
    if (!overlaps(o.occupied, a, b))
        return none;
    var mid = (a + b) / 2;
    var slots = freeSlots(o.total, o.occupied);
    for (var i = 0; i < slots.length; i++) {
        var s = slots[i];
        if (mid >= s[0] && mid <= s[1] && s[1] - s[0] >= o.length) {
            var to = Math.min(Math.max(a, s[0]), s[1] - o.length);
            return { mode: "shift", along: Math.round(to - a), across: 0 };
        }
    }
    return { mode: "drop", along: 0, across: Math.max(0, Math.round((o.barDepth || 0) + (o.gap || 0) - (o.edgeGap || 0))) };
}

// Screen translation {x, y} of a result of avoid() on edge `pos`
function offset(pos, r) {
    var along = r ? r.along : 0;
    var across = r ? r.across : 0;
    switch (pos) {
    case "bottom":
        return { x: along, y: -across };
    case "left":
        return { x: across, y: along };
    case "right":
        return { x: -across, y: along };
    default:
        return { x: along, y: across };
    }
}

// Hover bridge of a dropped notch: from the screen edge to the dropped
// notch, as wide as the resting notch `rest` {x, y, w, h} (so the pointer
// that opened it from its resting place keeps it open on the way down,
// without the whole grown width over the bar holding it). `reach` = px
// from the edge to the dropped notch.
function stem(pos, rest, reach, screen) {
    var d = Math.max(0, reach);
    switch (pos) {
    case "bottom":
        return { x: rest.x, y: screen.h - d, w: rest.w, h: d };
    case "left":
        return { x: 0, y: rest.y, w: d, h: rest.h };
    case "right":
        return { x: screen.w - d, y: rest.y, w: d, h: rest.h };
    default:
        return { x: rest.x, y: 0, w: rest.w, h: d };
    }
}
