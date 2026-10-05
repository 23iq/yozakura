.pragma library

// Style-aware placement for the desktop clock.
//
// scripts/depth_mask.py emits, per screen size, a coarse grid of the
// wallpaper as it is shown (PreserveAspectCrop):
//   grid = { cols, rows, cover: "<hex>", lum: "<hex>"[, jitter: "<hex>"] }
// one byte (two hex chars) per cell, row-major: `cover` is the subject
// alpha (for video mattes: a high percentile over the whole loop, i.e. the
// worst case), `lum` the backdrop luminance and `jitter` (videos) the mean
// frame-to-frame mask change. Every style is scored here against
// its own geometry (ClockStyleRegistry layout()), so switching styles never
// re-runs the script.

var MAX_COVER = 0.3;       // any digit group hidden more than this: draw in front
var LIGHT_BACKDROP = 0.55; // mean luminance above which the clock uses dark ink
var BOUNDS_WEIGHT = 0.5;   // the in-front parts may sit on the subject, but less is better
var SIDE_BIAS = 0.04;      // tie-break towards the preferred side
// Videos: mean mask change per frame inside a digit group above which the
// segmentation flickers there (the subject would pop in and out in front of
// the time), so the clock stays in front.
var MAX_INSTABILITY = 0.05;

function cell(hex, i) {
    return parseInt(hex.substr(i * 2, 2), 16) / 255;
}

function validChannel(grid, channel) {
    return typeof grid[channel] === "string" && grid[channel].length === grid.cols * grid.rows * 2;
}

function validGrid(grid) {
    return !!grid && grid.cols > 0 && grid.rows > 0 && validChannel(grid, "cover") && validChannel(grid, "lum");
}

// Area-weighted mean of one channel over a screen-pixel box.
function boxMean(grid, channel, b, screenW, screenH) {
    if (!validGrid(grid) || !validChannel(grid, channel) || !b || screenW <= 0 || screenH <= 0)
        return 0;
    var hex = grid[channel];
    var cw = screenW / grid.cols;
    var ch = screenH / grid.rows;
    var x0 = Math.max(0, b.x), y0 = Math.max(0, b.y);
    var x1 = Math.min(screenW, b.x + b.w), y1 = Math.min(screenH, b.y + b.h);
    if (x1 <= x0 || y1 <= y0)
        return 0;
    var c0 = Math.floor(x0 / cw), c1 = Math.min(grid.cols - 1, Math.floor((x1 - 1e-6) / cw));
    var r0 = Math.floor(y0 / ch), r1 = Math.min(grid.rows - 1, Math.floor((y1 - 1e-6) / ch));
    var sum = 0, wsum = 0;
    for (var r = r0; r <= r1; r++) {
        var oy = Math.min(y1, (r + 1) * ch) - Math.max(y0, r * ch);
        for (var c = c0; c <= c1; c++) {
            var ox = Math.min(x1, (c + 1) * cw) - Math.max(x0, c * cw);
            var w = ox * oy;
            if (w <= 0)
                continue;
            sum += cell(hex, r * grid.cols + c) * w;
            wsum += w;
        }
    }
    return wsum > 0 ? sum / wsum : 0;
}

function coverage(grid, b, screenW, screenH) {
    return boxMean(grid, "cover", b, screenW, screenH);
}

function luminance(grid, b, screenW, screenH) {
    return boxMean(grid, "lum", b, screenW, screenH);
}

// Pick a side for `style` (a ClockStyleRegistry entry).
//   opts = { screenW, screenH, areas: {left: {x,y,w,h}, right: {...}},
//            position: "auto"|"left"|"right", preferSide, use12h }
// returns { side, layout, coverage, reach, instability, depth, light, measured }
//   coverage:    worst subject coverage over the style's legible parts
//   reach:       subject coverage of the whole behind part (0: never there)
//   instability: worst mask flicker over the legible parts (videos)
function choose(style, grid, opts) {
    var sides = style.sides && style.sides.length ? style.sides : ["right"];
    var forced = sides.indexOf(opts.position) !== -1 ? opts.position : null;
    var prefer = sides.indexOf(opts.preferSide) !== -1 ? opts.preferSide : sides[0];
    var candidates = forced ? [forced] : sides;
    var measured = validGrid(grid);
    var best = null;
    for (var i = 0; i < candidates.length; i++) {
        var side = candidates[i];
        var area = (opts.areas && opts.areas[side]) || {
            x: 0,
            y: 0,
            w: opts.screenW,
            h: opts.screenH
        };
        var layout = style.layout({
            screenW: opts.screenW,
            screenH: opts.screenH,
            area: area,
            side: side,
            use12h: !!opts.use12h
        });
        layout.styleId = style.id;
        var cov = 0, jit = 0, reach = 0, score = side === prefer ? 0 : SIDE_BIAS;
        if (measured) {
            var parts = layout.legible && layout.legible.length ? layout.legible : [layout.behind];
            for (var p = 0; p < parts.length; p++) {
                cov = Math.max(cov, coverage(grid, parts[p], opts.screenW, opts.screenH));
                jit = Math.max(jit, boxMean(grid, "jitter", parts[p], opts.screenW, opts.screenH));
            }
            reach = coverage(grid, layout.behind, opts.screenW, opts.screenH);
            // A spot that keeps the clock behind the subject wins over one
            // that has to draw it in front.
            var usable = cov <= MAX_COVER && jit <= MAX_INSTABILITY;
            score += reach + BOUNDS_WEIGHT * coverage(grid, layout.bounds, opts.screenW, opts.screenH) + (usable ? 0 : 1);
        }
        if (!best || score < best.score) {
            best = {
                side: side,
                layout: layout,
                coverage: cov,
                reach: reach,
                instability: jit,
                score: score
            };
        }
    }
    best.measured = measured;
    // Without a mask the subject is unknown: keep the clock in front.
    best.depth = measured && !!style.needsDepth && best.coverage <= MAX_COVER && best.instability <= MAX_INSTABILITY;
    best.light = measured && luminance(grid, best.layout.bounds, opts.screenW, opts.screenH) > LIGHT_BACKDROP;
    return best;
}
