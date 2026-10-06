.pragma library

// Edge-aware placement math, the only place it lives. Pure functions of
//   e = { screen: {w, h}, frame: px,
//         bar:   {pos, size, visible}, dock: {pos, size, visible},
//         notch: {pos, height, visible} }
// where pos is "top" | "bottom" | "left" | "right" and notch.align is
// "start" | "center" | "end".

var OPPOSITE = { top: "bottom", bottom: "top", left: "right", right: "left" };
var VERTICAL = { left: true, right: true };

function insets(e) {
    var f = e.frame || 0;
    var r = { top: f, right: f, bottom: f, left: f };
    if (e.bar && e.bar.visible)
        r[e.bar.pos] += e.bar.size;
    if (e.dock && e.dock.visible)
        r[e.dock.pos] += e.dock.size;
    if (e.notch && e.notch.visible)
        r[e.notch.pos] += e.notch.height;
    return r;
}

function workArea(e) {
    var i = insets(e);
    return {
        x: i.left,
        y: i.top,
        w: Math.max(0, e.screen.w - i.left - i.right),
        h: Math.max(0, e.screen.h - i.top - i.bottom)
    };
}

function _clamp(v, lo, hi) {
    return Math.max(lo, Math.min(v, Math.max(lo, hi)));
}

// Position of a popup of `size` next to `anchor`, on the side facing away from
// `edge`. Flips to the opposite side when it does not fit there, and is always
// clamped inside the screen.
function popupPlacement(anchor, size, edge, e, gap) {
    var s = e.screen;
    var g = gap || 0;
    var dir = OPPOSITE[edge] === undefined ? "down" : { top: "down", bottom: "up", left: "right", right: "left" }[edge];

    function room(d) {
        if (d === "down") return s.h - (anchor.y + anchor.h + g);
        if (d === "up") return anchor.y - g;
        if (d === "right") return s.w - (anchor.x + anchor.w + g);
        return anchor.x - g;
    }
    var need = (dir === "down" || dir === "up") ? size.h : size.w;
    var flipped = false;
    if (room(dir) < need) {
        var other = { down: "up", up: "down", left: "right", right: "left" }[dir];
        if (room(other) > room(dir)) {
            dir = other;
            flipped = true;
        }
    }

    var x, y;
    if (dir === "down" || dir === "up") {
        x = anchor.x + (anchor.w - size.w) / 2;
        y = dir === "down" ? anchor.y + anchor.h + g : anchor.y - g - size.h;
    } else {
        y = anchor.y + (anchor.h - size.h) / 2;
        x = dir === "right" ? anchor.x + anchor.w + g : anchor.x - g - size.w;
    }
    return {
        x: Math.round(_clamp(x, 0, s.w - size.w)),
        y: Math.round(_clamp(y, 0, s.h - size.h)),
        dir: dir,
        flipped: flipped
    };
}

// Side a settings/notification sheet slides in from.
function sheetSide(e, pref) {
    if (pref === "left" || pref === "right")
        return pref;
    if (e.bar && e.bar.visible && e.bar.pos === "right")
        return "left";
    return "right";
}

// Full-height side sheet inside the work area, on sheetSide(e, pref).
function sheetRect(e, pref, width) {
    var w = workArea(e);
    var side = sheetSide(e, pref);
    var rw = Math.min(width, w.w);
    return {
        x: side === "right" ? w.x + w.w - rw : w.x,
        y: w.y,
        w: rw,
        h: w.h,
        side: side
    };
}

function spotlightRect(e, size) {
    var w = workArea(e);
    var rw = Math.min(size.w, w.w);
    var rh = Math.min(size.h, w.h);
    return {
        x: Math.round(w.x + (w.w - rw) / 2),
        y: Math.round(w.y + (w.h - rh) / 2),
        w: rw,
        h: rh
    };
}

function _occupied(e, edge, withNotch) {
    return !!((e.bar && e.bar.visible && e.bar.pos === edge) || (e.dock && e.dock.visible && e.dock.pos === edge) || (withNotch && e.notch && e.notch.visible && e.notch.pos === edge));
}

// Edge for an OSD: the preference, or the first free edge (bottom first).
function osdPlacement(e, pref, size) {
    var edge = pref;
    if (!OPPOSITE[edge]) {
        var order = ["bottom", "top", "right", "left"];
        var pick = null;
        var pass;
        for (pass = 0; pass < 2 && !pick; pass++) {
            for (var i = 0; i < order.length && !pick; i++) {
                if (!_occupied(e, order[i], pass === 0))
                    pick = order[i];
            }
        }
        edge = pick || "bottom";
    }
    var w = workArea(e);
    var margin = 24;
    var x, y;
    if (VERTICAL[edge]) {
        x = edge === "left" ? w.x + margin : w.x + w.w - size.w - margin;
        y = w.y + (w.h - size.h) / 2;
    } else {
        x = w.x + (w.w - size.w) / 2;
        y = edge === "top" ? w.y + margin : w.y + w.h - size.h - margin;
    }
    return { edge: edge, x: Math.round(x), y: Math.round(y), vertical: !!VERTICAL[edge] };
}

// Corner for toasts/widgets: the one touching the fewest occupied edges.
function freeCorner(e, pref) {
    if (pref && pref !== "auto")
        return pref;
    var corners = ["top-right", "top-left", "bottom-right", "bottom-left"];
    var best = corners[0];
    var bestScore = Infinity;
    for (var i = 0; i < corners.length; i++) {
        var parts = corners[i].split("-");
        var score = 0;
        for (var j = 0; j < parts.length; j++) {
            if (_occupied(e, parts[j], false))
                score += 2;
            else if (_occupied(e, parts[j], true))
                score += 1;
        }
        if (score < bestScore) {
            bestScore = score;
            best = corners[i];
        }
    }
    return best;
}

// Direction the notch's panels open in: toward the screen center.
function notchOpenDir(pos) {
    return { top: "down", bottom: "up", left: "right", right: "left" }[pos] || "down";
}

// Rect of a notch of `size` = {along, across} (along the edge / away from
// it) on e.notch.pos, aligned start | center | end (e.notch.align) along
// the edge. Center is the screen center; start/end hug the ends left free
// by a bar or dock on the perpendicular edges. A start notch keeps its
// start when it grows, an end notch its end, a centered one its center,
// so panels always grow toward the middle of the screen.
function notchRect(e, size) {
    var n = e.notch || {};
    var pos = OPPOSITE[n.pos] ? n.pos : "top";
    var vertical = !!VERTICAL[pos];
    var s = e.screen;
    var total = vertical ? s.h : s.w;
    var lo = vertical ? "top" : "left";
    var hi = vertical ? "bottom" : "right";
    function reserved(edge) {
        var r = e.frame || 0;
        if (e.bar && e.bar.visible && e.bar.pos === edge)
            r += e.bar.size;
        if (e.dock && e.dock.visible && e.dock.pos === edge)
            r += e.dock.size;
        return r;
    }
    var min = reserved(lo);
    var max = total - reserved(hi);
    var along = Math.min(size.along, total);
    var start;
    if (n.align === "start")
        start = min;
    else if (n.align === "end")
        start = max - along;
    else
        start = (total - along) / 2;
    start = Math.round(_clamp(start, Math.min(min, total - along), Math.max(0, max - along)));
    var across = Math.min(size.across, vertical ? s.w : s.h);
    if (vertical)
        return { x: pos === "left" ? 0 : s.w - across, y: start, w: across, h: along, vertical: true, dir: notchOpenDir(pos) };
    return { x: start, y: pos === "top" ? 0 : s.h - across, w: along, h: across, vertical: false, dir: notchOpenDir(pos) };
}
