.pragma library

// Is any wallpaper pixel visible on a monitor? Pure helpers for
// WallpaperCoverage.qml; unit tested in tests/wallpaper-coverage.test.cjs.
//
// The wallpaper counts as covered when the windows of the monitor's active
// workspace (tiled or floating, not hidden), each grown by its border,
// cover the whole monitor except `insets`: edge strips the shell itself
// paints over with opaque surfaces. Any gap (gaps_out, gaps_in, an empty
// corner) leaves wallpaper visible, so the video keeps playing.

// Logical rect of an yozd monitor ({x, y, width, height, scale, transform}).
function monitorRect(mon) {
    if (!mon)
        return null;
    var scale = mon.scale > 0 ? mon.scale : 1;
    var w = (mon.width || 0) / scale;
    var h = (mon.height || 0) / scale;
    if ((mon.transform || 0) % 2 === 1) {
        var t = w;
        w = h;
        h = t;
    }
    return { x: mon.x || 0, y: mon.y || 0, w: w, h: h };
}

// True when the union of `rects` ({x, y, w, h}) covers `target` entirely.
// Exact (coordinate compression): every cell of the grid made by all rect
// edges inside the target must lie in some rect.
function rectCovered(target, rects) {
    if (!target || target.w <= 0 || target.h <= 0)
        return true;
    var tx2 = target.x + target.w;
    var ty2 = target.y + target.h;
    var xs = [target.x, tx2];
    var ys = [target.y, ty2];
    var live = [];
    for (var i = 0; i < rects.length; i++) {
        var r = rects[i];
        if (!r || r.w <= 0 || r.h <= 0)
            continue;
        if (r.x >= tx2 || r.y >= ty2 || r.x + r.w <= target.x || r.y + r.h <= target.y)
            continue;
        live.push(r);
        if (r.x > target.x && r.x < tx2)
            xs.push(r.x);
        if (r.x + r.w > target.x && r.x + r.w < tx2)
            xs.push(r.x + r.w);
        if (r.y > target.y && r.y < ty2)
            ys.push(r.y);
        if (r.y + r.h > target.y && r.y + r.h < ty2)
            ys.push(r.y + r.h);
    }
    if (live.length === 0)
        return false;
    xs.sort(function (a, b) { return a - b; });
    ys.sort(function (a, b) { return a - b; });
    for (var xi = 0; xi + 1 < xs.length; xi++) {
        if (xs[xi + 1] <= xs[xi])
            continue;
        var cx = (xs[xi] + xs[xi + 1]) / 2;
        for (var yi = 0; yi + 1 < ys.length; yi++) {
            if (ys[yi + 1] <= ys[yi])
                continue;
            var cy = (ys[yi] + ys[yi + 1]) / 2;
            var hit = false;
            for (var k = 0; k < live.length && !hit; k++) {
                var q = live[k];
                hit = cx >= q.x && cx <= q.x + q.w && cy >= q.y && cy <= q.y + q.h;
            }
            if (!hit)
                return false;
        }
    }
    return true;
}

// mon: yozd monitor (see monitorRect, plus id and activeWorkspace.id)
// windows: YozdService client list ({monitor, workspace.id, hidden, at, size})
// insets: {top, bottom, left, right} opaque shell strips (px, logical)
// border: window border width drawn around each window
function covered(mon, windows, insets, border) {
    var rect = monitorRect(mon);
    if (!rect || rect.w <= 0 || rect.h <= 0 || !mon.activeWorkspace)
        return false;
    var ins = insets || {};
    var top = Math.max(0, ins.top || 0);
    var bottom = Math.max(0, ins.bottom || 0);
    var left = Math.max(0, ins.left || 0);
    var right = Math.max(0, ins.right || 0);
    var target = {
        x: rect.x + left,
        y: rect.y + top,
        w: rect.w - left - right,
        h: rect.h - top - bottom
    };
    var b = Math.max(0, border || 0);
    var wsId = mon.activeWorkspace.id;
    var rects = [];
    var list = windows || [];
    for (var i = 0; i < list.length; i++) {
        var win = list[i];
        if (!win || win.hidden || win.monitor !== mon.id || !win.workspace || win.workspace.id !== wsId)
            continue;
        var at = win.at || [0, 0];
        var size = win.size || [0, 0];
        if (!(size[0] > 0 && size[1] > 0))
            continue;
        rects.push({ x: at[0] - b, y: at[1] - b, w: size[0] + 2 * b, h: size[1] + 2 * b });
    }
    return rectCovered(target, rects);
}
