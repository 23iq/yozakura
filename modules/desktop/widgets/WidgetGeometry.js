.pragma library
.import "../../widgets/dashboard/wallpapers/WallpaperCoverage.js" as Coverage

// Geometry of desktop widgets: relative <-> pixel rects, snapping, drag and
// resize clamping, overlap with the depth clock, monitor assignment, free
// spot search and window coverage. Pure; tests/desktop-widgets.test.cjs.
//
// Rects are {x, y, w, h}. A widget's stored rect is relative (fractions of
// its screen); everything else here works in screen pixels.

function rect(x, y, w, h) {
    return {
        x: x,
        y: y,
        w: w,
        h: h
    };
}

function toPixels(widget, screenW, screenH) {
    return rect(Math.round(widget.x * screenW), Math.round(widget.y * screenH), Math.round(widget.w * screenW), Math.round(widget.h * screenH));
}

function round4(v) {
    return Math.round(v * 10000) / 10000;
}

function toRelative(r, screenW, screenH) {
    var sw = Math.max(1, screenW);
    var sh = Math.max(1, screenH);
    return {
        x: round4(r.x / sw),
        y: round4(r.y / sh),
        w: round4(r.w / sw),
        h: round4(r.h / sh)
    };
}

function snap(v, grid) {
    return grid > 0 ? Math.round(v / grid) * grid : Math.round(v);
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// `start` moved by (dx, dy), snapped to the grid and kept inside `bounds`
// (a widget never leaves its screen).
function moved(start, dx, dy, bounds, grid) {
    var x = snap(start.x + dx - bounds.x, grid) + bounds.x;
    var y = snap(start.y + dy - bounds.y, grid) + bounds.y;
    x = clamp(x, bounds.x, bounds.x + bounds.w - start.w);
    y = clamp(y, bounds.y, bounds.y + bounds.h - start.h);
    return rect(x, y, start.w, start.h);
}

// `start` grown by (dw, dh) from its top-left corner: snapped (the far edge
// lands on the grid), at least `min` ({w, h}) and inside `bounds`.
function resized(start, dw, dh, min, bounds, grid) {
    var right = snap(start.x + start.w + dw - bounds.x, grid) + bounds.x;
    var bottom = snap(start.y + start.h + dh - bounds.y, grid) + bounds.y;
    var w = clamp(right - start.x, min.w, bounds.x + bounds.w - start.x);
    var h = clamp(bottom - start.y, min.h, bounds.y + bounds.h - start.y);
    return rect(start.x, start.y, w, h);
}

function intersection(a, b) {
    if (!a || !b)
        return 0;
    var w = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
    var h = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    return w > 0 && h > 0 ? w * h : 0;
}

function overlaps(a, b) {
    return intersection(a, b) > 0;
}

// Screen a widget is shown on: its own monitor when connected, else the
// first screen (presets made elsewhere still show their widgets).
function screenFor(widget, screenNames) {
    var names = screenNames || [];
    if (names.length === 0)
        return "";
    return names.indexOf(widget.monitor) !== -1 ? widget.monitor : names[0];
}

function forScreen(list, screenName, screenNames) {
    return (list || []).filter(function (w) {
        return screenFor(w, screenNames) === screenName;
    });
}

// First free spot for a `size` rect inside `bounds`, scanning columns from
// the right edge (icons fill from the left) top to bottom, avoiding every
// rect in `taken` (other widgets, the depth clock). Falls back to the
// top-right corner when the screen is full.
function freeSpot(size, bounds, taken, grid, margin) {
    var m = margin || 0;
    var step = Math.max(8, grid > 0 ? grid : 24);
    var maxX = bounds.x + bounds.w - size.w - m;
    var maxY = bounds.y + bounds.h - size.h - m;
    for (var x = maxX; x >= bounds.x + m; x -= step) {
        for (var y = bounds.y + m; y <= maxY; y += step) {
            var r = rect(snap(x - bounds.x, grid) + bounds.x, snap(y - bounds.y, grid) + bounds.y, size.w, size.h);
            if (r.x + r.w > bounds.x + bounds.w || r.y + r.h > bounds.y + bounds.h)
                continue;
            var grown = rect(r.x - m, r.y - m, r.w + 2 * m, r.h + 2 * m);
            var free = true;
            for (var i = 0; i < taken.length && free; i++)
                free = !overlaps(grown, taken[i]);
            if (free)
                return r;
        }
    }
    return rect(Math.max(bounds.x, maxX), bounds.y + m, size.w, size.h);
}

// Whether the windows of the monitor's active workspace hide the widget
// (`r` in screen pixels, `mon` an yozd monitor, `windows` the client list).
function covered(r, mon, windows) {
    if (!mon || !mon.activeWorkspace || !r)
        return false;
    var origin = Coverage.monitorRect(mon);
    var target = rect(origin.x + r.x, origin.y + r.y, r.w, r.h);
    var wsId = mon.activeWorkspace.id;
    var rects = [];
    (windows || []).forEach(function (win) {
        if (!win || win.hidden || win.monitor !== mon.id || !win.workspace || win.workspace.id !== wsId)
            return;
        var at = win.at || [0, 0];
        var size = win.size || [0, 0];
        if (size[0] > 0 && size[1] > 0)
            rects.push(rect(at[0], at[1], size[0], size[1]));
    });
    return Coverage.rectCovered(target, rects);
}
