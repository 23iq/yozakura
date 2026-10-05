.pragma library

// Clock and cluster placement for a style's arrangement. Same rules as the
// shell (modules/lockscreen/LockLayout.js), which the greeter cannot import.
//
// ctx = { arrangement, clockSide, atTop, width, height, margin,
//         clockW, clockH, clusterW, clusterH, statusH }

var ARRANGEMENTS = ["stack", "center", "split", "column"];

function place(ctx) {
    var W = ctx.width, H = ctx.height, m = ctx.margin;
    var kw = ctx.clockW, kh = ctx.clockH, cw = ctx.clusterW, ch = ctx.clusterH;
    var side = Math.round(m * 1.6);
    var arrangement = ARRANGEMENTS.indexOf(ctx.arrangement) === -1 ? "stack" : ctx.arrangement;
    if (arrangement === "split" && kw + cw + side * 3 > W)
        arrangement = "stack";
    var edgeClusterY = ctx.atTop ? m * 1.6 : H - ch - m * 1.2;
    var statusBand = (ctx.statusH > 0 ? ctx.statusH + m * 0.75 : 0) + m * 0.5;
    var out = {
        "arrangement": arrangement
    };
    if (arrangement === "stack") {
        out.clusterX = (W - cw) / 2;
        out.clusterY = edgeClusterY;
        out.clockX = (W - kw) / 2;
        out.clockY = ctx.atTop ? Math.max(H * 0.6 - kh / 2, edgeClusterY + ch + m) : Math.min(H * 0.38 - kh / 2, edgeClusterY - kh - m);
    } else if (arrangement === "split") {
        var clockLeft = ctx.clockSide !== "right";
        out.clockX = clockLeft ? side : W - kw - side;
        out.clockY = (H - kh) / 2;
        out.clusterX = clockLeft ? W - cw - side : side;
        out.clusterY = edgeClusterY;
    } else {
        var gap = Math.round(m * 0.8);
        var total = kh + gap + ch;
        var top = (H - total) / 2 - H * 0.03;
        if (ctx.atTop)
            top = Math.min(top, H - statusBand - total);
        else
            top = Math.max(top, statusBand);
        var left = arrangement === "column";
        out.clockX = left ? side : (W - kw) / 2;
        out.clusterX = left ? side : (W - cw) / 2;
        if (ctx.atTop) {
            out.clusterY = top;
            out.clockY = top + ch + gap;
        } else {
            out.clockY = top;
            out.clusterY = top + kh + gap;
        }
    }
    out.clockX = Math.round(out.clockX);
    out.clockY = Math.round(out.clockY);
    out.clusterX = Math.round(out.clusterX);
    out.clusterY = Math.round(out.clusterY);
    return out;
}
