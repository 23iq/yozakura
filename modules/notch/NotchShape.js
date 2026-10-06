.pragma library

// Silhouette math of the notch on any screen edge ("top" | "bottom" |
// "left" | "right"). A side notch is laid out for its edge, never rotated;
// only the attached style's concave-corner mask and outline, which are
// drawn for a top/bottom edge, are turned (frame()). Unit tested in
// tests/notch-shape.test.cjs.

var EDGES = { top: true, bottom: true, left: true, right: true };

function edgeOf(pos) {
    return EDGES[pos] ? pos : "top";
}

function opposite(pos) {
    return { top: "bottom", bottom: "top", left: "right", right: "left" }[edgeOf(pos)];
}

function vertical(pos) {
    var p = edgeOf(pos);
    return p === "left" || p === "right";
}

// Corner radii {tl, tr, bl, br}: `edgeR` on the two corners touching the
// screen edge, `outerR` on the two facing the screen center.
function radii(pos, edgeR, outerR) {
    var p = edgeOf(pos);
    var onEdge = {
        top: { tl: 1, tr: 1 },
        bottom: { bl: 1, br: 1 },
        left: { tl: 1, bl: 1 },
        right: { tr: 1, br: 1 }
    }[p];
    var r = {};
    ["tl", "tr", "bl", "br"].forEach(function (k) {
        r[k] = onEdge[k] ? edgeR : outerR;
    });
    return r;
}

// Outer size of a notch whose content is `content` {w, h}, plus the two
// concave screen corners of `corner` px at its ends along the edge.
function size(pos, content, corner) {
    var c = Math.max(0, corner || 0) * 2;
    return vertical(pos) ? { w: content.w, h: content.h + c } : { w: content.w + c, h: content.h };
}

// Drawing frame of the corner mask and outline: they are written for a
// top/bottom edge, so a side notch draws the top shape `w` x `h` (along x
// across) and turns it so its flat side lies on the screen edge.
function frame(pos, w, h) {
    var p = edgeOf(pos);
    if (p === "left")
        return { w: h, h: w, rotation: -90, edge: "top" };
    if (p === "right")
        return { w: h, h: w, rotation: 90, edge: "top" };
    return { w: w, h: h, rotation: 0, edge: p };
}

// Translation that hides the notch behind its edge (`extent` = its depth).
function hideOffset(pos, extent) {
    var d = Math.max(extent, 50) + 16;
    var p = edgeOf(pos);
    return {
        x: p === "left" ? -d : p === "right" ? d : 0,
        y: p === "top" ? -d : p === "bottom" ? d : 0
    };
}

// Position of an expanded view of `view` {w, h} inside the notch `box`
// {w, h}: `inset` from the screen edge, centered along it.
function viewPos(pos, box, view, inset) {
    var p = edgeOf(pos);
    var cx = (box.w - view.w) / 2;
    var cy = (box.h - view.h) / 2;
    if (p === "left")
        return { x: inset, y: cy };
    if (p === "right")
        return { x: box.w - view.w - inset, y: cy };
    return { x: cx, y: p === "top" ? inset : box.h - view.h - inset };
}

// Hover strip that reveals a hidden notch: `depth` px into the notch from
// the screen edge (spanning a bar or frame in between), `pad` px wider than
// the notch `r` along the edge.
function hoverStrip(pos, r, screen, depth, pad) {
    var p = edgeOf(pos);
    if (p === "left" || p === "right") {
        var x = p === "left" ? 0 : r.x + r.w - depth;
        var w = p === "left" ? r.x + depth : screen.w - x;
        return { x: x, y: r.y - pad, w: w, h: r.h + pad * 2 };
    }
    var y = p === "top" ? 0 : r.y + r.h - depth;
    var h = p === "top" ? r.y + depth : screen.h - y;
    return { x: r.x - pad, y: y, w: r.w + pad * 2, h: h };
}
