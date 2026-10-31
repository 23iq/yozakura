.pragma library

// Geometry and state of the "branch" workspace indicator
// (workspaces.indicatorStyle = "branch"): a thin tapered branch through the
// workspace slots, a bud or blossom per workspace. Pure functions; every
// length derives from the slot size. Coordinates are local to the slot strip
// (no widget padding), along x; vertical strips swap x and y.

var SHAPES = ["sakura", "plum", "round", "leaf"];
var ROLES = ["primary", "secondary", "tertiary"];
// Petal positions of a blossom: an occupied workspace fills one per window.
var MAX_PETALS = 5;

function shape(id) {
    return SHAPES.indexOf(id) !== -1 ? id : SHAPES[0];
}

function role(id) {
    return ROLES.indexOf(id) !== -1 ? id : ROLES[0];
}

// Deterministic noise in [-1, 1] (same strip, same branch on every start).
function jitter(i, salt) {
    var v = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
    return (v - Math.floor(v)) * 2 - 1;
}

// How a slot's node (IndicatorStyles.stripSlots entry) is drawn: "bud" (empty), "blossom" (one petal per
// window, at most MAX_PETALS) or "open" (the active workspace: every petal,
// full size). scale is the blossom's size against a fully open one.
function node(s) {
    var wins = Math.max(0, Math.floor((s && s.windows) || 0));
    var active = !!(s && s.active);
    var kind = active ? "open" : (wins > 0 ? "blossom" : "bud");
    return {
        "kind": kind,
        "petals": active ? MAX_PETALS : Math.min(MAX_PETALS, wins),
        "urgent": !!(s && s.urgent),
        "scale": kind === "open" ? 1 : (kind === "blossom" ? 0.78 : 0)
    };
}

// A window closed on the same workspace: a petal falls.
function petalFalls(prev, next) {
    return !!prev && !!next && prev.id === next.id && next.windows < prev.windows;
}

// Centre of node i: the slot centre, nudged across the strip (alternating,
// with a little noise) so the branch undulates through the nodes.
function centre(i, slot, vertical) {
    var along = (i + 0.5) * slot;
    var across = slot / 2 + ((i % 2 === 0) ? 1 : -1) * slot * 0.05 + jitter(i, 1) * slot * 0.025;
    return vertical ? { "x": across, "y": along } : { "x": along, "y": across };
}

function _fmt(v) {
    return (Math.round(v * 100) / 100).toString();
}

// Spine of the branch (along/across pairs): enters from the trunk side a
// little below the first node, passes every node and ends in a short tip.
function spine(count, slot) {
    var pts = [{ "a": slot * 0.04, "c": slot * 0.62 }];
    for (var i = 0; i < count; i++) {
        var p = centre(i, slot, false);
        pts.push({ "a": p.x, "c": p.y });
    }
    var last = pts[pts.length - 1];
    pts.push({ "a": count * slot - slot * 0.04, "c": last.c + (count % 2 === 0 ? 1 : -1) * slot * 0.1 });
    return pts;
}

// Points along the spine (Catmull-Rom through its points), with t in [0, 1].
function samples(pts, perSegment) {
    var out = [];
    var n = pts.length;
    for (var k = 0; k < n - 1; k++) {
        var p0 = pts[Math.max(0, k - 1)], p1 = pts[k], p2 = pts[k + 1], p3 = pts[Math.min(n - 1, k + 2)];
        for (var s = 0; s < perSegment; s++) {
            var t = s / perSegment, t2 = t * t, t3 = t2 * t;
            var h = function (a, b, c, d) {
                return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
            };
            out.push({ "a": h(p0.a, p1.a, p2.a, p3.a), "c": h(p0.c, p1.c, p2.c, p3.c) });
        }
    }
    out.push({ "a": pts[n - 1].a, "c": pts[n - 1].c });
    for (var j = 0; j < out.length; j++)
        out[j].t = out.length > 1 ? j / (out.length - 1) : 0;
    return out;
}

// Stroke width of the branch: thick at the trunk side, a fine tip.
function width(t, slot) {
    var base = Math.max(1.6, slot * 0.075);
    var tip = Math.max(0.6, slot * 0.02);
    // a softly rounded cut end, then a long taper to the tip
    var cut = 0.6 + 0.4 * Math.min(1, t * 14);
    return (base + (tip - base) * Math.pow(t, 0.8)) * cut;
}

// The branch as a filled, tapered outline (SVG path data).
function branchPath(count, slot, vertical) {
    if (count < 1 || !(slot > 0))
        return "";
    var pts = samples(spine(count, slot), 10);
    var left = [], right = [];
    for (var i = 0; i < pts.length; i++) {
        var prev = pts[Math.max(0, i - 1)], next = pts[Math.min(pts.length - 1, i + 1)];
        var da = next.a - prev.a, dc = next.c - prev.c;
        var len = Math.sqrt(da * da + dc * dc) || 1;
        var na = -dc / len, nc = da / len;
        var hw = width(pts[i].t, slot) / 2;
        left.push([pts[i].a + na * hw, pts[i].c + nc * hw]);
        right.push([pts[i].a - na * hw, pts[i].c - nc * hw]);
    }
    var ring = left.concat(right.reverse());
    var d = "";
    for (var j = 0; j < ring.length; j++) {
        var x = vertical ? ring[j][1] : ring[j][0];
        var y = vertical ? ring[j][0] : ring[j][1];
        d += (j === 0 ? "M" : "L") + _fmt(x) + " " + _fmt(y) + " ";
    }
    return d + "Z";
}

// Outline of one petal in its own frame: u runs from the blossom centre (0)
// to the tip (len), v across it (full width w).
function petalOutline(kind, len, w) {
    var L = len, W = w;
    switch (shape(kind)) {
    case "plum":
        return [["M", 0, 0], ["C", 0.1 * L, -0.62 * W, L, -0.6 * W, L, 0], ["C", L, 0.6 * W, 0.1 * L, 0.62 * W, 0, 0]];
    case "round":
        var r = 0.3 * L, cu = 0.66 * L, k = 0.5523 * r;
        return [["M", cu - r, 0], ["C", cu - r, -k, cu - k, -r, cu, -r], ["C", cu + k, -r, cu + r, -k, cu + r, 0],
            ["C", cu + r, k, cu + k, r, cu, r], ["C", cu - k, r, cu - r, k, cu - r, 0]];
    case "leaf":
        return [["M", 0, 0], ["C", 0.3 * L, -0.42 * W, 0.7 * L, -0.34 * W, L, 0], ["C", 0.7 * L, 0.34 * W, 0.3 * L, 0.42 * W, 0, 0]];
    default:
        // sakura: a rounded petal with the notched tip
        return [["M", 0, 0], ["C", 0.3 * L, -0.58 * W, 0.92 * L, -0.56 * W, L, -0.17 * W], ["L", 0.86 * L, 0],
            ["L", L, 0.17 * W], ["C", 0.92 * L, 0.56 * W, 0.3 * L, 0.58 * W, 0, 0]];
    }
}

// Petal width against its length, per shape (sakura and plum petals touch
// their neighbours when the blossom is fully open).
function petalWidth(kind) {
    return ({ "sakura": 0.78, "plum": 0.82, "round": 1, "leaf": 0.5 })[shape(kind)];
}

// Angle (degrees, 0 = up, clockwise) of petal position p of node i.
function petalAngle(i, p) {
    return p * (360 / MAX_PETALS) + jitter(i, 2) * 18;
}

// SVG path data of petals [from, to) of a blossom centred at (cx, cy):
// each one rotated to its position around the centre.
function petalsPath(kind, i, from, to, cx, cy, len) {
    var d = "";
    var w = len * petalWidth(kind);
    var outline = petalOutline(kind, len, w);
    for (var p = from; p < to; p++) {
        var a = petalAngle(i, p) * Math.PI / 180;
        var du = [Math.sin(a), -Math.cos(a)], dv = [Math.cos(a), Math.sin(a)];
        for (var c = 0; c < outline.length; c++) {
            var cmd = outline[c];
            d += cmd[0];
            for (var q = 1; q < cmd.length; q += 2) {
                var x = cx + du[0] * cmd[q] + dv[0] * cmd[q + 1];
                var y = cy + du[1] * cmd[q] + dv[1] * cmd[q + 1];
                d += _fmt(x) + " " + _fmt(y) + " ";
            }
        }
        d += "Z ";
    }
    return d.trim();
}

// A closed bud: a small teardrop leaning off the branch (alternating sides).
function budPath(i, cx, cy, len) {
    var tilt = ((i % 2 === 0) ? -1 : 1) * (28 + jitter(i, 3) * 10);
    var a = tilt * Math.PI / 180;
    var du = [Math.sin(a), -Math.cos(a)], dv = [Math.cos(a), Math.sin(a)];
    var L = len, W = len * 0.62;
    var outline = [["M", -0.1 * L, 0], ["C", -0.1 * L, -0.55 * W, 0.55 * L, -0.5 * W, L, 0], ["C", 0.55 * L, 0.5 * W, -0.1 * L, 0.55 * W, -0.1 * L, 0]];
    var d = "";
    for (var c = 0; c < outline.length; c++) {
        d += outline[c][0];
        for (var q = 1; q < outline[c].length; q += 2) {
            d += _fmt(cx + du[0] * outline[c][q] + dv[0] * outline[c][q + 1]) + " " + _fmt(cy + du[1] * outline[c][q] + dv[1] * outline[c][q + 1]) + " ";
        }
    }
    return d + "Z";
}

// Petal length of a fully open blossom in a slot.
function bloomRadius(slot) {
    return slot * 0.4;
}

// Urgency must read with any palette (error is close to pink on the default
// one), so it never depends on hue alone: a halo ring around the blossom and
// a stamen, each in the alert role when that contrasts with what it sits on
// (WCAG ratio >= MIN_CONTRAST), else in whichever of `ink`/`alt` does.
var MIN_CONTRAST = 3;

function _lin(v) {
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

// Relative luminance of a colour ({r, g, b} in 0..1, as a QML color).
function luminance(c) {
    return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
}

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// `color` when readable on `ground`, else the better of `ink` and `alt`.
function readable(color, ground, ink, alt) {
    if (contrast(color, ground) >= MIN_CONTRAST)
        return color;
    return contrast(ink, ground) >= contrast(alt, ground) ? ink : alt;
}

// Halo radius and stroke width of an urgent blossom (inside the slot).
function haloRadius(slot) {
    return slot * 0.455;
}

function haloWidth(slot) {
    return Math.max(1, slot * 0.07);
}

// Where a falling petal ends (relative to where it starts): down the
// screen with a little sideways drift and a turn.
function fall(i, slot) {
    return { "dx": (jitter(i, 4) >= 0 ? 1 : -1) * slot * (0.2 + Math.abs(jitter(i, 4)) * 0.2), "dy": slot * 0.9, "turn": 110 + jitter(i, 5) * 50 };
}
