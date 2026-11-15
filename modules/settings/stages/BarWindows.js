.pragma library

// The windows a vertical bar is shown through on the Bar stage (BarStage):
// the bar stands at its true size on a screen as tall as yours, far longer
// than the stage is tall, so the stage shows pieces of it side by side: its
// top end, its middle when a module sits there, its bottom end.
// Pure; tests/settings-bar-windows.test.cjs.

// Spans along the bar ([{y, len}], native px) of a bar `length` long seen
// through windows `len` long; `modules` [{y, h}] (native) decide whether a
// middle window is needed (a module neither end shows).
function windows(length, len, modules) {
    var L = Math.max(0, Number(length) || 0);
    var w = Math.max(1, Number(len) || 1);
    if (L <= w)
        return [{ "y": 0, "len": L }];
    var out = [{ "y": 0, "len": w }];
    var lo = Infinity, hi = -Infinity;
    (modules || []).forEach(function (m) {
        var c = m.y + m.h / 2;
        if (c > w && c < L - w) {
            lo = Math.min(lo, m.y);
            hi = Math.max(hi, m.y + m.h);
        }
    });
    if (lo < hi) {
        var y = Math.max(0, Math.min(L - w, (lo + hi) / 2 - w / 2));
        out.push({ "y": y, "len": w });
    }
    out.push({ "y": L - w, "len": w });
    return out;
}

// Where each window stands in a stage `width` x `height`: `colW` wide (stage
// px), `gap` apart, the row centred; the window's height is its span at
// `zoom`, centred vertically.
function place(spans, width, height, colW, zoom, gap) {
    var n = (spans || []).length;
    if (n === 0)
        return [];
    var total = n * colW + (n - 1) * gap;
    var x0 = Math.round((width - total) / 2);
    return spans.map(function (s, i) {
        var h = s.len * zoom;
        return { "x": x0 + i * (colW + gap), "y": Math.round((height - h) / 2), "w": colW, "h": h };
    });
}

// Module rects (native [{id, x, y, w, h}]) in stage px, each in the window
// that shows its middle (the first one); a module no window shows is left
// out, and a module cut by its window's end is clipped to it.
function mapModules(mods, spans, rects, zoom) {
    var out = [];
    (mods || []).forEach(function (m) {
        var c = m.y + m.h / 2;
        for (var i = 0; i < spans.length; i++) {
            var s = spans[i], r = rects[i];
            if (!r || c < s.y || c >= s.y + s.len)
                continue;
            var top = Math.max(r.y, r.y + (m.y - s.y) * zoom);
            var bottom = Math.min(r.y + r.h, r.y + (m.y + m.h - s.y) * zoom);
            out.push({ "id": m.id, "x": r.x + m.x * zoom, "y": top, "w": m.w * zoom, "h": Math.max(0, bottom - top) });
            break;
        }
    });
    return out;
}
