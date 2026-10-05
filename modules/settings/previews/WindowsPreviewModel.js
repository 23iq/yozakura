.pragma library

// Pure geometry/color helpers of the Windows page preview
// (WindowsPreview.qml). The preview draws what Hyprland draws, at 1:1
// pixels, from the very hl.config() table the shell applies
// (CompositorAppearance.buildHyprlandConfig). Node-tested
// (tests/windows-preview.test.cjs).

// Hyprland color literal ("rgb(rrggbb)", "rgba(rrggbbaa)") -> "#aarrggbb".
function qtColor(str) {
    var m = /^rgba?\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\)$/.exec(String(str || "").trim());
    if (!m)
        return "#00000000";
    return "#" + (m[2] || "ff") + m[1];
}

// Border value (string or {colors, angle}) -> {colors: [qt colors], angle}.
function border(value) {
    if (typeof value === "string")
        return {
            "colors": [qtColor(value)],
            "angle": 0
        };
    if (value && value.colors && value.colors.length)
        return {
            "colors": Array.prototype.map.call(value.colors, qtColor),
            "angle": Number(value.angle) || 0
        };
    return {
        "colors": ["#00000000"],
        "angle": 0
    };
}

// Gradient line for a CSS-like angle (0deg = left to right, clockwise as y
// grows down) across a w x h box, from edge to edge through the center.
function gradientLine(angle, w, h) {
    var a = angle * Math.PI / 180;
    var dx = Math.cos(a), dy = Math.sin(a);
    var half = (Math.abs(dx) * w + Math.abs(dy) * h) / 2;
    return {
        "x1": w / 2 - dx * half,
        "y1": h / 2 - dy * half,
        "x2": w / 2 + dx * half,
        "y2": h / 2 + dy * half
    };
}

// Two tiled windows on a w x h monitor slice: the border's outer edge sits
// gaps_out from the monitor edge and 2 x gaps_in from the neighbour.
function tiles(w, h, gapsIn, gapsOut) {
    var gi = Math.max(0, gapsIn), go = Math.max(0, gapsOut);
    var inner = w - 2 * go;
    var each = Math.max(0, (inner - 2 * gi) / 2);
    var y = go, height = Math.max(0, h - 2 * go);
    return [
        {
            "x": go,
            "y": y,
            "w": each,
            "h": height
        },
        {
            "x": go + each + 2 * gi,
            "y": y,
            "w": each,
            "h": height
        }
    ];
}

// One window filling the slice (smart gaps drop every gap).
function single(w, h, gapsOut) {
    var go = Math.max(0, gapsOut);
    return {
        "x": go,
        "y": go,
        "w": Math.max(0, w - 2 * go),
        "h": Math.max(0, h - 2 * go)
    };
}

// "x y" -> {x, y}.
function offset(str) {
    var p = String(str || "0 0").trim().split(/\s+/).map(Number);
    return {
        "x": isFinite(p[0]) ? p[0] : 0,
        "y": isFinite(p[1]) ? p[1] : 0
    };
}

// Hyprland's kawase blur grows with size x sqrt(passes); MultiEffect's 0..1.
function blurAmount(blur) {
    if (!blur || !blur.enabled)
        return 0;
    return Math.min(1, blur.size * Math.sqrt(blur.passes) / 28);
}
