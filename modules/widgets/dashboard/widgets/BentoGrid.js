.pragma library

// Pure bento layout: cells are {widget, x, y, w, h} in grid units, one per
// widget id. `registry` is a widget registry module (byId, defaultGrid; see
// WidgetRegistry.js). Every edit returns a new normalized array: sizes are
// clamped to the widget limits and the column count, overlaps are pushed
// down and everything is compacted upward, so a hand-edited or corrupt
// grid can never break the layout.

function _int(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? Math.round(n) : fallback;
}

function _clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function _cols(cols) {
    return Math.max(1, _int(cols, 4));
}

function _hit(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function _free(c, placed) {
    for (var i = 0; i < placed.length; i++)
        if (placed[i] !== c && _hit(c, placed[i]))
            return false;
    return true;
}

function _sanitize(cell, cols, registry) {
    var def = cell && typeof cell === "object" ? registry.byId(cell.widget) : null;
    if (!def)
        return null;
    var w = _clamp(_int(cell.w, def.defaultW), Math.min(def.minW, cols), Math.min(def.maxW, cols));
    var h = _clamp(_int(cell.h, def.defaultH), def.minH, def.maxH);
    return {
        widget: def.id,
        x: _clamp(_int(cell.x, 0), 0, cols - w),
        y: Math.max(0, _int(cell.y, 0)),
        w: w,
        h: h
    };
}

function _byPosition(a, b) {
    return a.y - b.y || a.x - b.x;
}

// Lays the cells out: `pinned` (a widget id) keeps its spot, the others are
// placed in reading order and pushed down until free, then all compact up.
function _resolve(cells, pinned) {
    var order = cells.slice().sort(_byPosition);
    var placed = [];
    var pin = null;
    for (var i = 0; i < order.length; i++)
        if (order[i].widget === pinned)
            pin = order[i];
    if (pin)
        placed.push(pin);
    for (var j = 0; j < order.length; j++) {
        var c = order[j];
        if (c === pin)
            continue;
        while (!_free(c, placed))
            c.y++;
        placed.push(c);
    }
    placed.sort(_byPosition);
    for (var k = 0; k < placed.length; k++) {
        var p = placed[k];
        while (p.y > 0) {
            p.y--;
            if (!_free(p, placed)) {
                p.y++;
                break;
            }
        }
    }
    return placed.sort(_byPosition);
}

function normalize(cells, cols, registry) {
    var n = _cols(cols);
    var out = [];
    var seen = {};
    var list = Array.isArray(cells) ? cells : [];
    for (var i = 0; i < list.length; i++) {
        var c = _sanitize(list[i], n, registry);
        if (c && !seen[c.widget]) {
            seen[c.widget] = true;
            out.push(c);
        }
    }
    if (out.length === 0) {
        var def = registry.defaultGrid(n);
        for (var j = 0; j < def.length; j++)
            out.push(_sanitize(def[j], n, registry));
    }
    return _resolve(out, "");
}

function _edit(cells, id, cols, registry, patch) {
    var n = _cols(cols);
    var base = normalize(cells, n, registry);
    var found = false;
    var next = base.map(function (c) {
        if (c.widget !== id)
            return c;
        found = true;
        return _sanitize(patch(c), n, registry);
    });
    return found ? _resolve(next, id) : base;
}

function move(cells, id, x, y, cols, registry) {
    return _edit(cells, id, cols, registry, function (c) {
        return { widget: c.widget, x: x, y: y, w: c.w, h: c.h };
    });
}

function resize(cells, id, w, h, cols, registry) {
    return _edit(cells, id, cols, registry, function (c) {
        return { widget: c.widget, x: c.x, y: c.y, w: Math.max(1, _int(w, c.w)), h: Math.max(1, _int(h, c.h)) };
    });
}

function rows(cells) {
    var r = 0;
    var list = Array.isArray(cells) ? cells : [];
    for (var i = 0; i < list.length; i++)
        r = Math.max(r, list[i].y + list[i].h);
    return r;
}

function add(cells, widgetId, cols, registry) {
    var base = normalize(cells, cols, registry);
    var def = registry.byId(widgetId);
    if (!def || base.some(function (c) { return c.widget === widgetId; }))
        return base;
    return normalize(base.concat([{ widget: def.id, x: 0, y: rows(base), w: def.defaultW, h: def.defaultH }]), cols, registry);
}

function remove(cells, id) {
    return (Array.isArray(cells) ? cells : []).filter(function (c) { return c && c.widget !== id; });
}

// Registry widgets not on the grid yet (the picker's list).
function available(cells, registry) {
    var used = {};
    (Array.isArray(cells) ? cells : []).forEach(function (c) { if (c) used[c.widget] = true; });
    return registry.ids().filter(function (id) { return !used[id]; });
}

// Pixel position -> nearest cell, and pixel length -> cell span.
function snap(px, py, cellW, gap, cellH) {
    var sh = (cellH === undefined ? cellW : cellH) + gap;
    return { x: Math.max(0, Math.round(px / (cellW + gap))), y: Math.max(0, Math.round(py / sh)) };
}

function span(px, cell, gap) {
    return Math.max(1, Math.round((px + gap) / (cell + gap)));
}

function serialize(cells) {
    return (Array.isArray(cells) ? cells : []).map(function (c) {
        return { widget: c.widget, x: c.x, y: c.y, w: c.w, h: c.h };
    });
}
