.pragma library

// Pure geometry of the panorama ("emaki") wallpaper: one wide image, scaled
// to the screen height, with a viewport that pans to one slot per workspace.
// All x values are viewport left edges in screen pixels, 0..travel.

// Widest texture decoded for a panorama (most GPUs cap at 16384).
var MAX_TEXTURE = 16384;

// Parallax lead of each layer, as a fraction of the move: during a pan the
// nearer layers run ahead of the background by up to this much (a sine bump
// over the move), at rest every layer lines up again (no ghosting).
var LAYER_LEAD = [0, 0.015, 0.035];
// Depth (0 far .. 1 near) where each extra layer starts, and its soft edge.
var LAYER_DEPTHS = [0, 0.45, 0.72];
var LAYER_EDGE = 0.08;

// Size of the image as drawn: covers the screen height (or its width, for an
// image narrower than the screen), aspect kept.
// -> { width, height, y, travel }
function layout(imgW, imgH, screenW, screenH) {
    if (!(imgW > 0) || !(imgH > 0) || !(screenW > 0) || !(screenH > 0))
        return {
            width: screenW > 0 ? screenW : 0,
            height: screenH > 0 ? screenH : 0,
            y: 0,
            travel: 0
        };
    var s = Math.max(screenH / imgH, screenW / imgW);
    var w = imgW * s;
    var h = imgH * s;
    return {
        width: w,
        height: h,
        y: (screenH - h) / 2,
        travel: Math.max(0, w - screenW)
    };
}

// Pan step between neighbouring workspace frames: N workspaces span exactly
// the image (first frame at its left edge, last at its right edge), so frames
// never wrap around or reach past the image. An image narrower than the
// screen has no travel, hence no step.
function frameStep(count, travel) {
    if (!(travel > 0))
        return 0;
    var n = Math.max(1, Math.floor(count || 1));
    return travel / Math.max(1, n - 1);
}

// Viewport x of workspace slot `index` (0-based) out of `count`: index * step,
// clamped into 0..travel. A single workspace sits centred. Every parallax
// layer starts and ends its pan on these same x values (layerX).
function slotX(index, count, travel, screenW) {
    if (!(travel > 0))
        return 0;
    var n = Math.max(1, Math.floor(count || 1));
    if (n === 1)
        return travel / 2;
    var i = Math.max(0, Math.min(n - 1, Math.floor(index || 0)));
    return Math.min(travel, i * frameStep(n, travel));
}

// Where this monitor sits in its workspace list -> { index, count }.
// perMonitor (niri): workspaces are a per-output list in display order, the
// active one is found by position. Otherwise (Hyprland, MangoWC) ids are the
// slots, and `shown` workspaces always exist.
function slot(perMonitor, monitor, workspaces, shown) {
    var activeId = monitor && monitor.activeWorkspace ? (monitor.activeWorkspace.id || 0) : 0;
    if (perMonitor) {
        var name = monitor ? monitor.name : "";
        var mine = (workspaces || []).filter(function (w) {
            return w && w.monitor === name;
        });
        var at = -1;
        for (var k = 0; k < mine.length; k++) {
            if (mine[k].id === activeId)
                at = k;
        }
        return {
            index: Math.max(0, at),
            count: Math.max(1, mine.length)
        };
    }
    var id = Math.max(1, activeId);
    return {
        index: id - 1,
        count: Math.max(1, shown || 0, id)
    };
}

// Decode size for the panorama texture: the screen height, never wider than
// the texture cap (Qt fits the image inside it, aspect kept).
function decodeSize(screenH) {
    return {
        width: MAX_TEXTURE,
        height: Math.max(1, Math.round(screenH || 0))
    };
}

// Viewport x of parallax layer `layer` at eased pan progress p (0..1) of a
// move from `fromX` to `toX`.
function layerX(fromX, toX, p, layer) {
    var t = Math.max(0, Math.min(1, p));
    var d = toX - fromX;
    return fromX + d * t + d * (LAYER_LEAD[layer] || 0) * Math.sin(Math.PI * t);
}

// Path of the user-provided depth map next to an image: <name>.depth.png.
function depthMapPath(file) {
    if (!file)
        return "";
    var slash = file.lastIndexOf("/");
    var dot = file.lastIndexOf(".");
    var stem = dot > slash ? file.substring(0, dot) : file;
    return stem + ".depth.png";
}
