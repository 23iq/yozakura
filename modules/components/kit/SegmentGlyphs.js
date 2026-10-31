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

// Geometry of segment `i` (SEGMENTS order) in a w x h cell with bar
// thickness t: {x, y, w, h}. Horizontal bars sit between the vertical ones
// and every joint keeps a small gap, so no two bars overlap and each reads
// as its own segment.
function segment(i, w, h, t) {
    var g = Math.max(1, t * 0.22);
    var half = h / 2;
    var hx = t + g;
    var hw = Math.max(0, w - 2 * t - 2 * g);
    var vh = Math.max(0, half - t / 2 - g / 2);
    switch (SEGMENTS[i]) {
    case "a":
        return { x: hx, y: 0, w: hw, h: t };
    case "b":
        return { x: w - t, y: t / 2, w: t, h: vh };
    case "c":
        return { x: w - t, y: half + g / 2, w: t, h: vh };
    case "d":
        return { x: hx, y: h - t, w: hw, h: t };
    case "e":
        return { x: 0, y: half + g / 2, w: t, h: vh };
    case "f":
        return { x: 0, y: t / 2, w: t, h: vh };
    default:
        return { x: hx, y: half - t / 2, w: hw, h: t };
    }
}
