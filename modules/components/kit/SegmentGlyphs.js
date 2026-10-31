.pragma library

// Seven-segment glyphs for SegmentDigits. Segments are named
//
//      a
//    f   b
//      g
//    e   c
//      d
//
// and a glyph is the list of lit segments. Unknown characters (and the
// space) light nothing: the cell shows only its dim "off" segments.
// Unit tested in tests/segment-glyphs.test.cjs.

var SEGMENTS = ["a", "b", "c", "d", "e", "f", "g"];

var GLYPHS = {
    "0": "abcdef",
    "1": "bc",
    "2": "abdeg",
    "3": "abcdg",
    "4": "bcfg",
    "5": "acdfg",
    "6": "acdefg",
    "7": "abc",
    "8": "abcdefg",
    "9": "abcdfg",
    "-": "g",
    "_": "d",
    "A": "abcefg",
    "B": "cdefg",
    "C": "adef",
    "D": "bcdeg",
    "E": "adefg",
    "F": "aefg",
    "H": "bcefg",
    "L": "def",
    "O": "abcdef",
    "P": "abefg",
    "U": "bcdef"
};

// Characters drawn as narrow dots between cells instead of as a digit.
var SEPARATORS = {
    ":": true,
    ".": true
};

function lit(ch) {
    var g = GLYPHS[String(ch).toUpperCase()];
    return g === undefined ? "" : g;
}

// [7 booleans] in SEGMENTS order.
function mask(ch) {
    var on = lit(ch);
    return SEGMENTS.map(function (s) {
        return on.indexOf(s) >= 0;
    });
}

function isSeparator(ch) {
    return SEPARATORS[ch] === true;
}

// A bar along its centreline from (x0, y0) to (x1, y1) (horizontal or
// vertical), t thick, with pointed ends: a hexagon as [[x, y], ...].
function bar(x0, y0, x1, y1, t) {
    var r = t / 2;
    if (y0 === y1)
        return [[x0, y0], [x0 + r, y0 - r], [x1 - r, y0 - r], [x1, y0], [x1 - r, y0 + r], [x0 + r, y0 + r]];
    return [[x0, y0], [x0 + r, y0 + r], [x0 + r, y1 - r], [x0, y1], [x0 - r, y1 - r], [x0 - r, y0 + r]];
}

// Outline of segment `i` (SEGMENTS order) in a w x h cell with bar
// thickness t: a pointed hexagon, [[x, y], ...]. Bars run between the
// centrelines of their neighbours and stop a small gap short of each joint,
// so they meet at mitred tips like a real LCD and never touch.
function polygon(i, w, h, t) {
    var g = Math.max(0.6, t * 0.2);
    var r = t / 2;
    var half = h / 2;
    var left = r, right = w - r, top = r, bottom = h - r;
    switch (SEGMENTS[i]) {
    case "a":
        return bar(left + g, top, right - g, top, t);
    case "b":
        return bar(right, top + g, right, half - g, t);
    case "c":
        return bar(right, half + g, right, bottom - g, t);
    case "d":
        return bar(left + g, bottom, right - g, bottom, t);
    case "e":
        return bar(left, half + g, left, bottom - g, t);
    case "f":
        return bar(left, top + g, left, half - g, t);
    default:
        return bar(left + g, half, right - g, half, t);
    }
}
