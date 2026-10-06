.pragma library

// OSD style registry and the small pure helpers the styles share. Each style
// is its own component under styles/; OSD.qml loads one through a Loader.

var STYLES = ["pill", "edge", "island", "bar-inline"];
var FILES = {
    "pill": "styles/OsdPill.qml",
    "edge": "styles/OsdEdge.qml",
    "island": "styles/OsdIsland.qml",
    "bar-inline": "styles/OsdBarInline.qml"
};

function normalize(style) {
    return STYLES.indexOf(style) >= 0 ? style : "pill";
}

function fileFor(style) {
    return FILES[normalize(style)];
}

// ctx: {inlineAvailable, islandHandled}. `window` says whether the OSD
// window itself shows anything: bar-inline lives in the bar and the island
// in the notch when those hosts exist; otherwise the window shows the style
// (island) or falls back to the pill (bar-inline without a bar widget).
function resolve(style, ctx) {
    var c = ctx || {};
    var s = normalize(style);
    if (s === "bar-inline")
        return c.inlineAvailable ? { "style": s, "window": false } : { "style": "pill", "window": true };
    if (s === "island")
        return { "style": s, "window": !c.islandHandled };
    return { "style": s, "window": true };
}

// Edge preference handed to EdgeLayout.osdPlacement: the island sits on the
// notch's edge unless the user picked one.
function edgePref(style, pref, notchPos) {
    if (normalize(style) === "island" && (!pref || pref === "auto"))
        return notchPos === "bottom" ? "bottom" : "top";
    return pref || "auto";
}

// Window-content size for a style, given whether the chosen edge is vertical.
function sizeFor(style, vertical, osdW) {
    var w = osdW > 0 ? osdW : 220;
    switch (normalize(style)) {
    case "edge":
        return vertical ? { "w": 56, "h": Math.round(w * 1.1) } : { "w": w, "h": 56 };
    case "island":
        return { "w": Math.round(w * 0.82), "h": 44 };
    default:
        return { "w": w, "h": 52 };
    }
}

function clamp01(v) {
    return Math.max(0, Math.min(1, +v || 0));
}

function percent(v) {
    return Math.round(clamp01(v) * 100);
}

function wheelStep(deltaY) {
    return deltaY > 0 ? 0.05 : deltaY < 0 ? -0.05 : 0;
}

function deviceName(node) {
    if (!node)
        return "";
    return node.description || node.nickname || node.name || "";
}

function deviceSwitched(previous, current) {
    return !!previous && !!current && previous !== current;
}

// "muted" is distinct from "zero" (level 0 but not muted).
function stateOf(kind, value, muted) {
    if (muted && kind !== "brightness")
        return "muted";
    return value <= 0 ? "zero" : "on";
}

function labelKey(kind) {
    return kind === "mic" ? "osd.mic" : kind === "brightness" ? "osd.brightness" : "osd.volume";
}
