.pragma library

// Silhouette of a bar style for the Shape pictures (BarShapeThumb.qml): the
// bar drawn alone, big, with three or four simple marks (dots, a word, app
// squares) so the styles differ by outline at a glance, not by detail.
//
// shape(style, L, t) -> {shapes: [{x, y, w, h, r, kind}], marks: [{x, y, w, h, r, kind}]}
// in the frame of a bar on the top edge: x runs along the edge (0..L), y
// away from it; `t` is the bar's thickness. A shape may start above the edge
// (y < 0) or past the ends (x < 0, x + w > L): that part is cut off by the
// picture, so only its far corners show rounded (a tab grown from the edge).
// kind: shape "band" | "dock" | "ghost" (no bar: an outline where it would be);
// mark "dot" | "word" | "app" | "seg".

// Contents of one shape: groups [{at: "start"|"center"|"end", marks: [kind]}]
var CONTENT = {
    "bar": [{ "at": "start", "marks": ["dot", "dot", "dot"] }, { "at": "end", "marks": ["word"] }],
    "tabStart": [{ "at": "center", "marks": ["dot", "dot"] }],
    "tabCenter": [{ "at": "center", "marks": ["word"] }],
    "dock": [{ "at": "center", "marks": ["app", "app", "app", "app"] }],
    "menubar": [{ "at": "start", "marks": ["word", "word"] }, { "at": "end", "marks": ["dot", "word"] }],
    "statusline": [{ "at": "start", "marks": ["seg", "seg"] }, { "at": "end", "marks": ["word"] }],
    "ribbon": [{ "at": "start", "marks": ["word"] }, { "at": "end", "marks": ["word"] }],
    "rail": [{ "at": "start", "marks": ["dot", "dot", "dot"] }, { "at": "end", "marks": ["dot"] }]
};

function markSize(kind, t) {
    switch (kind) {
    case "word":
        return { "w": t * 0.9, "h": t * 0.2, "r": t * 0.1 };
    case "app":
        return { "w": t * 0.5, "h": t * 0.5, "r": t * 0.14 };
    case "seg":
        return { "w": t * 0.9, "h": t * 0.42, "r": t * 0.08 };
    default:
        return { "w": t * 0.26, "h": t * 0.26, "r": t * 0.13 };
    }
}

function runLength(kinds, t, gap) {
    var len = 0;
    for (var i = 0; i < kinds.length; i++)
        len += markSize(kinds[i], t).w + (i > 0 ? gap : 0);
    return len;
}

// The marks of a group that fit in `room`: words become dots first, then
// marks drop from the end (a short shape: a side bar, a small tab).
function fit(marks, room, t, gap) {
    var kinds = marks.slice();
    while (kinds.length > 0 && runLength(kinds, t, gap) > room) {
        var w = kinds.lastIndexOf("word");
        if (w !== -1)
            kinds[w] = "dot";
        else
            kinds.pop();
    }
    return kinds;
}

// Lay the content groups of a shape out in its visible box.
function fill(box, content, t) {
    var out = [];
    var gap = t * 0.18;
    var pad = Math.min(box.h * 0.45, t * 0.3);
    for (var g = 0; g < content.length; g++) {
        var group = content[g];
        var kinds = fit(group.marks, (box.w - pad) / content.length - (content.length > 1 ? gap : 0), t, gap);
        var sizes = kinds.map(function (k) {
            return markSize(k, t);
        });
        var len = runLength(kinds, t, gap);
        var x = group.at === "start" ? box.x + pad : (group.at === "end" ? box.x + box.w - pad - len : box.x + (box.w - len) / 2);
        for (var j = 0; j < sizes.length; j++) {
            var s = sizes[j];
            out.push({
                "x": x,
                "y": box.y + (box.h - s.h) / 2,
                "w": s.w,
                "h": s.h,
                "r": s.r,
                "kind": kinds[j]
            });
            x += s.w + gap;
        }
    }
    return out;
}

// Shapes before clipping: [x, y, w, h, r, kind, content, visible box]
function outline(style, L, t) {
    var g = Math.round(t * 0.3);
    var r = Math.round(t * 0.45);
    var tab = Math.round(L * 0.3);
    var mid = Math.round(L * 0.26);
    var thin = Math.round(t * 0.72);
    function s(x, y, w, h, rad, kind, content, box) {
        return { "x": x, "y": y, "w": w, "h": h, "r": rad, "kind": kind, "content": content, "box": box || { "x": x, "y": y, "w": w, "h": h } };
    }
    switch (style) {
    case "floating":
        return [s(g, g, L - 2 * g, t - g, Math.round((t - g) * 0.35), "band", "bar")];
    case "islands":
        return [s(-r, -r, tab + r, t + r, r, "band", "tabStart", { "x": 0, "y": 0, "w": tab, "h": t }), s((L - mid) / 2, -r, mid, t + r, r, "band", "tabCenter", { "x": (L - mid) / 2, "y": 0, "w": mid, "h": t }), s(L - tab, -r, tab + r, t + r, r, "band", "tabStart", { "x": L - tab, "y": 0, "w": tab, "h": t })];
    case "pills":
        var ph = t - g;
        return [s(g, g, tab - g, ph, ph / 2, "band", "tabStart"), s((L - mid) / 2, g, mid, ph, ph / 2, "band", "tabCenter"), s(L - tab, g, tab - g, ph, ph / 2, "band", "tabStart")];
    case "dock-like":
    case "dock":
        var dw = Math.round(L * 0.5);
        return [s((L - dw) / 2, g, dw, t - g, Math.round(t * 0.3), "dock", "dock")];
    case "menubar":
        return [s(0, 0, L, thin, 0, "band", "menubar", { "x": 0, "y": 0, "w": L, "h": thin })];
    case "statusline":
        return [s(0, 0, L, thin, 0, "band", "statusline")];
    case "ribbon":
        return [s(0, 0, L, Math.round(t * 0.8), 0, "band", "ribbon")];
    case "rail":
        return [s(0, 0, L, t, 0, "band", "rail")];
    case "corners":
        return [s(-r, -r, tab + r, t + r, r, "band", "tabStart", { "x": 0, "y": 0, "w": tab, "h": t }), s(L - tab, -r, tab + r, t + r, r, "band", "tabStart", { "x": L - tab, "y": 0, "w": tab, "h": t })];
    case "none":
        return [s(g, g, L - 2 * g, t - g, Math.round((t - g) * 0.35), "ghost", "")];
    default:
        // classic: the full band on the edge
        return [s(0, 0, L, t, 0, "band", "bar")];
    }
}

function shape(style, L, t) {
    var shapes = [];
    var marks = [];
    var list = outline(style, L, t);
    for (var i = 0; i < list.length; i++) {
        var o = list[i];
        shapes.push({ "x": o.x, "y": o.y, "w": o.w, "h": o.h, "r": o.r, "kind": o.kind });
        if (o.content && CONTENT[o.content])
            marks = marks.concat(fill(o.box, CONTENT[o.content], t));
    }
    return { "shapes": shapes, "marks": marks };
}
