.pragma library

// Corner style of a StyledRect. Pure: resolves the style from the variant
// config, theme.shape and the popup anchor edge. Styles:
//   round    - today's rounded rectangle (ClippingRectangle, no extra cost)
//   squircle - superellipse corners (corner_mask.frag)
//   cut      - chamfered corners of theme.shape.cutSize (corner_mask.frag)
//   tab      - round, with the corners on the anchor edge squared
// Unknown values fall back to round.

var STYLES = ["round", "squircle", "cut", "tab"];
var DEFAULT_CUT = 10;
var MIN_CUT = 2;
var MAX_CUT = 32;

// Corner order everywhere: [topLeft, topRight, bottomRight, bottomLeft].
var SQUARED_ON = {
    "top": [0, 1],
    "right": [1, 2],
    "bottom": [2, 3],
    "left": [3, 0]
};

function _valid(s) {
    return typeof s === "string" && STYLES.indexOf(s) !== -1;
}

function _cut(shape) {
    var v = shape ? shape.cutSize : undefined;
    if (typeof v !== "number" || isNaN(v))
        return DEFAULT_CUT;
    return Math.max(MIN_CUT, Math.min(MAX_CUT, Math.round(v)));
}

// variantCfg: Styling.getStyledRectConfig(variant) (optional `cornerStyle`);
// themeShape: Config.theme.shape {corners, popupCorners, cutSize};
// isPopup: popupCorners applies; anchorEdge: edge facing the anchor ("" none).
function resolve(variantCfg, themeShape, isPopup, anchorEdge) {
    var own = variantCfg ? variantCfg.cornerStyle : undefined;
    var style = "round";
    if (_valid(own))
        style = own;
    else if (isPopup && themeShape && _valid(themeShape.popupCorners))
        style = themeShape.popupCorners;
    else if (themeShape && _valid(themeShape.corners))
        style = themeShape.corners;

    var corners = [true, true, true, true];
    if (style === "tab" && SQUARED_ON[anchorEdge]) {
        var sq = SQUARED_ON[anchorEdge];
        corners[sq[0]] = false;
        corners[sq[1]] = false;
    }
    return {
        "style": style,
        "radius": variantCfg && typeof variantCfg.radius === "number" ? variantCfg.radius : 0,
        "cut": _cut(themeShape),
        "corners": corners
    };
}

// True when the SDF mask is needed (round with every corner styled keeps the
// plain ClippingRectangle path).
function needsMask(r) {
    if (!r || r.style === "round")
        return false;
    if (r.style === "tab")
        return r.corners.indexOf(false) !== -1;
    return true;
}

// Integer style id of corner_mask.frag (tab draws round corners).
function shaderStyle(style) {
    if (style === "squircle")
        return 1;
    if (style === "cut")
        return 2;
    return 0;
}

// Per-corner radii for the shader: [tl, tr, br, bl], 0 = square corner.
function radii(r, values) {
    var out = [];
    for (var i = 0; i < 4; i++) {
        var v = values ? values[i] : 0;
        if (typeof v !== "number" || isNaN(v) || v < 0)
            v = 0;
        out.push(r && r.corners && r.corners[i] === false ? 0 : v);
    }
    return out;
}
