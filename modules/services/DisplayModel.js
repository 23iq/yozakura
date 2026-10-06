.pragma library

// Pure helpers of the displays service (tests/display-model.test.cjs).
//
// Three shapes meet here:
//   output  what the compositor reports (displays.list): id, name, make,
//           model, enabled, width, height, refresh, x, y, scale, transform,
//           vrr (bool), modes [{width, height, refresh}], physical_*_mm.
//   config  one saved entry of displays.monitors (camelCase): id, name,
//           enabled, width, height, refresh, x, y, autoPosition, scale,
//           transform, vrr (0 off, 1 on, 2 fullscreen only).
//   wire    the backend's OutputConfig (auto_position in snake_case).

var SNAP_DISTANCE = 40;

function _num(v, fallback) {
    return (typeof v === "number" && isFinite(v)) ? v : fallback;
}

function _vrrInt(v) {
    if (v === true)
        return 1;
    return (typeof v === "number" && v >= 0 && v <= 2) ? Math.round(v) : 0;
}

// The saved form of a live output.
function outputToConfig(output) {
    return {
        "id": output.id || "",
        "name": output.name || "",
        "enabled": output.enabled !== false,
        "width": _num(output.width, 0),
        "height": _num(output.height, 0),
        "refresh": _num(output.refresh, 0),
        "x": _num(output.x, 0),
        "y": _num(output.y, 0),
        "autoPosition": false,
        "scale": _num(output.scale, 1),
        "transform": _num(output.transform, 0),
        "vrr": _vrrInt(output.vrr)
    };
}

// config -> backend OutputConfig.
function toWire(config) {
    return {
        "name": config.name,
        "enabled": config.enabled !== false,
        "width": _num(config.width, 0),
        "height": _num(config.height, 0),
        "refresh": _num(config.refresh, 0),
        "x": _num(config.x, 0),
        "y": _num(config.y, 0),
        "auto_position": config.autoPosition === true,
        "scale": _num(config.scale, 0),
        "transform": _num(config.transform, 0),
        "vrr": _vrrInt(config.vrr)
    };
}

// backend OutputConfig -> config. `outputs` supplies the stable id.
function fromWire(wire, outputs) {
    var id = "";
    for (var i = 0; i < (outputs || []).length; i++) {
        if (outputs[i].name === wire.name) {
            id = outputs[i].id || "";
            break;
        }
    }
    return {
        "id": id,
        "name": wire.name,
        "enabled": wire.enabled !== false,
        "width": _num(wire.width, 0),
        "height": _num(wire.height, 0),
        "refresh": _num(wire.refresh, 0),
        "x": _num(wire.x, 0),
        "y": _num(wire.y, 0),
        "autoPosition": wire.auto_position === true,
        "scale": _num(wire.scale, 0),
        "transform": _num(wire.transform, 0),
        "vrr": _vrrInt(wire.vrr)
    };
}

// Index of the matched output per saved entry (undefined = none).
function _match(list, outs) {
    var used = {};
    var matched = new Array(list.length);
    var i, j;
    // Passes, strictest first: id and name, id only, name only.
    var rules = [
        function (c, o) { return !!c.id && o.id === c.id && o.name === c.name; },
        function (c, o) { return !!c.id && o.id === c.id; },
        function (c, o) { return o.name === c.name; }
    ];
    for (var r = 0; r < rules.length; r++) {
        for (i = 0; i < list.length; i++) {
            if (!list[i] || matched[i] !== undefined)
                continue;
            for (j = 0; j < outs.length; j++) {
                if (!used[j] && rules[r](list[i], outs[j])) {
                    used[j] = true;
                    matched[i] = j;
                    break;
                }
            }
        }
    }
    return matched;
}


// Maps saved entries onto the connected outputs and returns them keyed by
// the CURRENT connector name. A saved entry matches by id first (several
// identical monitors without a serial share one id: each connected output
// is used once, preferring the one with the saved name), then by name.
// Entries without a connected output are dropped.
function resolveSaved(saved, outputs) {
    var list = saved || [];
    var outs = outputs || [];
    var matched = _match(list, outs);
    var result = [];
    for (var i = 0; i < list.length; i++) {
        if (matched[i] === undefined)
            continue;
        var cfg = {};
        for (var k in list[i])
            cfg[k] = list[i][k];
        cfg.name = outs[matched[i]].name;
        cfg.id = outs[matched[i]].id || cfg.id || "";
        result.push(cfg);
    }
    return result;
}

// What the compositor config renders: the saved entries keyed by current
// connector. Entries of disconnected monitors stay under their saved name
// (unless a connected output already uses it); with no live outputs known
// yet the saved list is used as is.
function renderList(saved, outputs) {
    var list = saved || [];
    var outs = outputs || [];
    if (outs.length === 0)
        return list.slice();
    var matched = _match(list, outs);
    var result = resolveSaved(list, outs);
    var taken = {};
    result.forEach(function (c) {
        taken[c.name] = true;
    });
    list.forEach(function (c, i) {
        if (matched[i] === undefined && c && !taken[c.name]) {
            taken[c.name] = true;
            result.push(c);
        }
    });
    return result;
}

// Distinct refresh rates (desc) the output offers at w x h.
function refreshesFor(output, w, h) {
    var seen = {};
    var rates = [];
    var modes = (output && output.modes) || [];
    for (var i = 0; i < modes.length; i++) {
        if (modes[i].width !== w || modes[i].height !== h)
            continue;
        var r = Math.round(modes[i].refresh * 100) / 100;
        if (!seen[r]) {
            seen[r] = true;
            rates.push(r);
        }
    }
    return rates.sort(function (a, b) {
        return b - a;
    });
}

// Distinct resolutions, largest first.
function resolutions(output) {
    var seen = {};
    var list = [];
    var modes = (output && output.modes) || [];
    for (var i = 0; i < modes.length; i++) {
        var key = modes[i].width + "x" + modes[i].height;
        if (seen[key])
            continue;
        seen[key] = true;
        list.push({
            "width": modes[i].width,
            "height": modes[i].height
        });
    }
    return list.sort(function (a, b) {
        return (b.width * b.height - a.width * a.height) || (b.width - a.width);
    });
}

// Scale from the pixel density of the current mode.
function suggestScale(output) {
    var mm = _num(output && output.physical_width_mm, 0);
    var px = _num(output && output.width, 0);
    if (mm <= 0 || px <= 0)
        return 1;
    var dpi = px / (mm / 25.4);
    if (dpi < 120)
        return 1;
    if (dpi < 170)
        return 1.25;
    if (dpi < 220)
        return 1.5;
    return 2;
}

function bestRefresh(output) {
    var rates = refreshesFor(output, output.width, output.height);
    return rates.length > 0 ? rates[0] : _num(output.refresh, 0);
}

function canUpgradeRefresh(output) {
    return bestRefresh(output) > _num(output.refresh, 0) + 1;
}

// Size in logical pixels: scaled, and swapped for 90/270 degree transforms.
function logicalSize(o) {
    var scale = _num(o.scale, 1) > 0 ? _num(o.scale, 1) : 1;
    var w = _num(o.width, 0) / scale;
    var h = _num(o.height, 0) / scale;
    if (_num(o.transform, 0) % 2 === 1) {
        var t = w;
        w = h;
        h = t;
    }
    return {
        "w": Math.round(w),
        "h": Math.round(h)
    };
}

function _rect(o) {
    var s = logicalSize(o);
    return {
        "x": o.x,
        "y": o.y,
        "w": s.w,
        "h": s.h
    };
}

function _nearest(value, candidates) {
    var best = value;
    var bestDist = SNAP_DISTANCE + 1;
    for (var i = 0; i < candidates.length; i++) {
        var d = Math.abs(candidates[i] - value);
        if (d < bestDist) {
            bestDist = d;
            best = candidates[i];
        }
    }
    return bestDist <= SNAP_DISTANCE ? best : value;
}

function _overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

// Pushes r out of o along the axis with the least penetration.
function _pushOut(r, o) {
    var left = o.x - (r.x + r.w);
    var right = (o.x + o.w) - r.x;
    var up = o.y - (r.y + r.h);
    var down = (o.y + o.h) - r.y;
    var best = [[Math.abs(left), "x", left], [Math.abs(right), "x", right], [Math.abs(up), "y", up], [Math.abs(down), "y", down]].sort(function (a, b) {
        return a[0] - b[0];
    })[0];
    r[best[1]] += best[2];
}

// Drops `movedName` at (x, y): snaps its edges to the other enabled outputs
// within SNAP_DISTANCE, pushes it out of any overlap and shifts everything
// so the minimum x and y are 0. Returns new configs; the input is untouched.
function arrange(outputs, movedName, x, y) {
    var result = outputs.map(function (o) {
        var c = {};
        for (var k in o)
            c[k] = o[k];
        return c;
    });
    var moved = null;
    for (var i = 0; i < result.length; i++) {
        if (result[i].name === movedName)
            moved = result[i];
    }
    if (!moved)
        return result;
    var others = result.filter(function (o) {
        return o !== moved && o.enabled !== false;
    }).map(_rect);
    var r = _rect(moved);
    r.x = Math.round(x);
    r.y = Math.round(y);
    var xs = [];
    var ys = [];
    others.forEach(function (o) {
        xs.push(o.x + o.w, o.x - r.w, o.x, o.x + o.w - r.w);
        ys.push(o.y + o.h, o.y - r.h, o.y, o.y + o.h - r.h);
    });
    r.x = _nearest(r.x, xs);
    r.y = _nearest(r.y, ys);
    for (var pass = 0; pass < 4; pass++) {
        var clear = true;
        for (var j = 0; j < others.length; j++) {
            if (_overlaps(r, others[j])) {
                _pushOut(r, others[j]);
                clear = false;
            }
        }
        if (clear)
            break;
    }
    moved.x = r.x;
    moved.y = r.y;
    moved.autoPosition = false;
    var minX = r.x;
    var minY = r.y;
    others.forEach(function (o) {
        minX = Math.min(minX, o.x);
        minY = Math.min(minY, o.y);
    });
    result.forEach(function (o) {
        if (o.enabled === false)
            return;
        o.x -= minX;
        o.y -= minY;
    });
    return result;
}

// Merges imported configs into the saved list: an entry replaces the saved
// one with the same id (when it has one) or else the same name; new ones are
// appended. Returns a new list.
function mergeSaved(saved, imported) {
    var merged = (saved || []).slice();
    (imported || []).forEach(function (cfg) {
        var at = -1;
        if (cfg.id) {
            for (var i = 0; i < merged.length && at < 0; i++) {
                if (merged[i].id === cfg.id && merged[i].name === cfg.name)
                    at = i;
            }
            for (var j = 0; j < merged.length && at < 0; j++) {
                if (merged[j].id === cfg.id)
                    at = j;
            }
        }
        for (var k = 0; k < merged.length && at < 0; k++) {
            if (merged[k].name === cfg.name)
                at = k;
        }
        if (at >= 0)
            merged[at] = cfg;
        else
            merged.push(cfg);
    });
    return merged;
}
