.pragma library

// OSD style registry and the small pure helpers the styles share. Each style
// is its own component under styles/; OSD.qml loads one through a Loader.

var STYLES = ["pill", "edge", "island", "bar-inline", "gauge"];
var FILES = {
    "pill": "styles/OsdPill.qml",
    "edge": "styles/OsdEdge.qml",
    "island": "styles/OsdIsland.qml",
    "bar-inline": "styles/OsdBarInline.qml",
    "gauge": "styles/OsdGauge.qml"
};

function normalize(style) {
    return STYLES.indexOf(style) >= 0 ? style : "pill";
}

function fileFor(style) {
    return FILES[normalize(style)];
}

// ctx: {inlineAvailable, islandHandled, notchEnabled}. `window` says
// whether the OSD window itself shows anything: bar-inline lives in the bar
// and the island in the notch when those hosts exist (the island only while
// the notch is on: notch.enabled false hides it, so the window shows the
// island-look pill itself); otherwise the window shows the style (island)
// or falls back to the pill (bar-inline without a bar widget).
function resolve(style, ctx) {
    var c = ctx || {};
    var s = normalize(style);
    if (s === "bar-inline")
        return c.inlineAvailable ? { "style": s, "window": false } : { "style": "pill", "window": true };
    if (s === "island")
        return { "style": s, "window": !(c.islandHandled && c.notchEnabled !== false) };
    return { "style": s, "window": true };
}

var EDGES = ["top", "bottom", "left", "right"];

// Edge preference handed to EdgeLayout.osdPlacement: unless the user picked
// one, the island sits on the notch's edge (a side notch included), and on
// the bar's edge while the notch is off (top without a bar).
function edgePref(style, pref, notchPos, notchEnabled, barEdge) {
    if (normalize(style) === "island" && (!pref || pref === "auto")) {
        var edge = notchEnabled === false ? barEdge : notchPos;
        return EDGES.indexOf(edge) !== -1 ? edge : "top";
    }
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
    case "gauge":
        // An upright instrument on every edge.
        return { "w": Math.round(w * 0.76), "h": Math.round(w * 0.76 * 0.98) };
    default:
        return vertical ? { "w": 52, "h": Math.round(w * 0.9) } : { "w": w, "h": 52 };
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

// "62%" (the value shown next to a level).
function valueText(v) {
    return percent(v) + "%";
}

// What a style shows next to the level, shared by every style:
//   title   the line above the level: the "Muted" label (accent), or the
//           new device right after an output switch; "" otherwise
//   caption the quiet line under the title: the current device when muted
//   value   "62%", "" when muted
//   level   whether the level line shows (hidden while muted)
//   accent  whether the title is the accent "Muted" label
function readout(kind, value, muted, device, currentDevice, mutedLabel) {
    if (stateOf(kind, value, muted) === "muted")
        return { "title": mutedLabel || "", "caption": currentDevice || "", "value": "", "level": false, "accent": true };
    return { "title": device || "", "caption": "", "value": valueText(value), "level": true, "accent": false };
}
