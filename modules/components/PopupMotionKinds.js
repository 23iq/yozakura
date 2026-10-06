.pragma library

// Popup entry kinds (theme.popup.entry), pure. A kind maps the motion
// progress t (0 hidden .. 1 at rest, may overshoot with OutBack) and the
// opening direction (EdgeLayout.popupPlacement dir: down | up | left | right)
// to a frame {opacity, scaleX, scaleY, dx, dy}. PopupMotion.qml applies it.

var KINDS = ["fade-scale", "slide-from-anchor", "morph-from-bar", "unfold"];
var DEFAULT = "fade-scale";

var ANCHOR_EDGE = {
    "down": "top",
    "up": "bottom",
    "right": "left",
    "left": "right"
};
// Unit vector from the popup toward its anchor
var TOWARD = {
    "down": [0, -1],
    "up": [0, 1],
    "right": [-1, 0],
    "left": [1, 0]
};

function kind(name) {
    return KINDS.indexOf(name) !== -1 ? name : DEFAULT;
}

function _dir(d) {
    return ANCHOR_EDGE[d] ? d : "down";
}

// Edge of the popup that faces its anchor
function anchorEdge(dir) {
    return ANCHOR_EDGE[_dir(dir)];
}

function _clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

function _axis(dir, along, across) {
    var vertical = dir === "down" || dir === "up";
    return vertical ? [across, along] : [along, across];
}

var _builders = {
    "fade-scale": function (dir, t) {
        var s = 0.9 + 0.1 * t;
        return {
            "opacity": _clamp01(t),
            "scaleX": s,
            "scaleY": s,
            "dx": 0,
            "dy": 0
        };
    },
    "slide-from-anchor": function (dir, t, slide) {
        var v = TOWARD[dir];
        var off = (1 - t) * slide;
        return {
            "opacity": _clamp01(t),
            "scaleX": 1,
            "scaleY": 1,
            "dx": v[0] * off + 0,
            "dy": v[1] * off + 0
        };
    },
    "morph-from-bar": function (dir, t) {
        var s = _axis(dir, 0.2 + 0.8 * t, 0.6 + 0.4 * t);
        return {
            "opacity": _clamp01(t * 2.5),
            "scaleX": Math.max(0.01, s[0]),
            "scaleY": Math.max(0.01, s[1]),
            "dx": 0,
            "dy": 0
        };
    },
    "unfold": function (dir, t) {
        var s = _axis(dir, t, 1);
        return {
            "opacity": _clamp01(t * 4),
            "scaleX": Math.max(0.01, s[0]),
            "scaleY": Math.max(0.01, s[1]),
            "dx": 0,
            "dy": 0
        };
    }
};

// slide: travel of slide-from-anchor in px
function frame(name, dir, t, slide) {
    var p = typeof t === "number" && !isNaN(t) ? t : 1;
    return _builders[kind(name)](_dir(dir), p, slide || 0);
}

// Transform origin on the anchor edge; `along` is the anchor's position
// along that edge in px (-1 = the middle), clamped to the popup.
function origin(dir, w, h, along) {
    var d = _dir(dir);
    var vertical = d === "down" || d === "up";
    var len = vertical ? w : h;
    var a = along < 0 ? len / 2 : Math.max(0, Math.min(len, along));
    if (d === "down")
        return { "x": a, "y": 0 };
    if (d === "up")
        return { "x": a, "y": h };
    if (d === "right")
        return { "x": 0, "y": a };
    return { "x": w, "y": a };
}
