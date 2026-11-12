.pragma library

// Geometry of the compact OSD window (performance.compactOsd): instead of a
// full-screen layer surface, a window just around the OSD, anchored to the
// edge EdgeLayout.osdPlacement picked plus the start edge across it (left
// for top/bottom, top for left/right), so its position is exact on every
// compositor (no centring of an odd remainder). The box holds the OSD at
// rest and where its slide starts (`distance` px towards its edge), plus
// `pad` px of slack around it (shadowPad: room for a theme drop shadow,
// which surfaces of the classic language cast), clamped to the screen.
// Unit tested in tests/osd-window-box.test.cjs.

var PAD = 4;
// MultiEffect's shadow reach at its default blurMax (Shadow.qml)
var SHADOW_REACH = 32;

// Slack for a shadow at the theme's light offset (Lighting.shadow*Offset)
function shadowPad(dx, dy) {
    return SHADOW_REACH + Math.ceil(Math.max(Math.abs(dx || 0), Math.abs(dy || 0))) + PAD;
}

// place {edge, x, y}; size {w, h}; distance: slide length (OsdSlide);
// screen {w, h}. -> {x, y, w, h (screen px), anchors {top, bottom, left,
// right}, margins {top, bottom, left, right}, offsetX, offsetY (where the
// OSD sits inside the window)}
function box(place, size, distance, screen, pad) {
    var p = pad === undefined ? PAD : pad;
    var d = Math.max(0, Math.ceil(distance || 0));
    var edge = place && place.edge ? place.edge : "bottom";
    var sw = Math.max(1, Math.round(screen && screen.w ? screen.w : 1));
    var sh = Math.max(1, Math.round(screen && screen.h ? screen.h : 1));
    var x0 = Math.floor(place.x) - p;
    var y0 = Math.floor(place.y) - p;
    var x1 = Math.ceil(place.x + size.w) + p;
    var y1 = Math.ceil(place.y + size.h) + p;
    if (edge === "top")
        y0 -= d;
    else if (edge === "bottom")
        y1 += d;
    else if (edge === "left")
        x0 -= d;
    else
        x1 += d;
    x0 = Math.max(0, Math.min(x0, sw - 1));
    y0 = Math.max(0, Math.min(y0, sh - 1));
    x1 = Math.max(x0 + 1, Math.min(x1, sw));
    y1 = Math.max(y0 + 1, Math.min(y1, sh));
    var vertical = edge === "left" || edge === "right";
    var a = {
        "top": vertical || edge === "top",
        "bottom": !vertical && edge === "bottom",
        "left": !vertical || edge === "left",
        "right": vertical && edge === "right"
    };
    return {
        "x": x0,
        "y": y0,
        "w": x1 - x0,
        "h": y1 - y0,
        "anchors": a,
        "margins": {
            "top": a.top ? y0 : 0,
            "bottom": a.bottom ? sh - y1 : 0,
            "left": a.left ? x0 : 0,
            "right": a.right ? sw - x1 : 0
        },
        "offsetX": place.x - x0,
        "offsetY": place.y - y0
    };
}

