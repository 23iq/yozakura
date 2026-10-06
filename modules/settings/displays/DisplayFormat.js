.pragma library
.import "../../services/DisplayModel.js" as DisplayModel

// Pure presentation helpers of the Displays page (tests/display-format.test.cjs).

var SCALES = [1, 1.25, 1.5, 1.75, 2, 3];
var ROTATIONS = [0, 1, 2, 3];

// "240 Hz", "59.94 Hz"
function formatHz(rate) {
    var r = Math.round(rate * 100) / 100;
    return (r % 1 === 0 ? String(r) : r.toFixed(2)) + " Hz";
}

function formatResolution(w, h) {
    return w + " × " + h;
}

function formatScale(s) {
    return Math.round(s * 100) + "%";
}

function resolutionKey(w, h) {
    return w + "x" + h;
}

function parseResolution(key) {
    var p = String(key).split("x");
    return {
        "width": parseInt(p[0], 10) || 0,
        "height": parseInt(p[1], 10) || 0
    };
}

// Selector options of the resolutions an output offers.
function resolutionOptions(output) {
    return DisplayModel.resolutions(output).map(function (r) {
        return {
            "value": resolutionKey(r.width, r.height),
            "label": formatResolution(r.width, r.height)
        };
    });
}

// Chip options for the refresh rates at the config's resolution; the
// highest one carries `max`.
function refreshOptions(output, config) {
    var rates = DisplayModel.refreshesFor(output, config.width, config.height);
    return rates.map(function (r, i) {
        return {
            "value": r,
            "label": formatHz(r),
            "max": i === 0 && rates.length > 1
        };
    });
}

// Scale chips: the common steps, the current value when it is not one of
// them, and a hint on the suggested one.
function scaleOptions(current, suggested) {
    var values = SCALES.slice();
    if (current > 0 && values.every(function (v) {
        return Math.abs(v - current) > 0.001;
    }))
        values.push(current);
    values.sort(function (a, b) {
        return a - b;
    });
    return values.map(function (v) {
        return {
            "value": v,
            "label": formatScale(v),
            "max": Math.abs(v - suggested) < 0.001
        };
    });
}

// Same tolerance the chips use to decide which one is lit.
function sameNumber(a, b) {
    return Math.abs(a - b) < 0.02;
}

// {name: 1-based index}: enabled outputs left to right, then top to
// bottom (the numbers identify() shows).
function numbering(configs) {
    var list = configs.filter(function (c) {
        return c.enabled !== false;
    }).slice().sort(function (a, b) {
        return (a.x - b.x) || (a.y - b.y);
    });
    var out = {};
    list.forEach(function (c, i) {
        out[c.name] = i + 1;
    });
    return out;
}

// Canvas mapping for the enabled outputs: logical px -> canvas px.
// The world is the bounding box plus drag room on every side.
function fitLayout(configs, width, height) {
    var minX = Infinity;
    var minY = Infinity;
    var maxX = -Infinity;
    var maxY = -Infinity;
    var biggest = 0;
    configs.forEach(function (c) {
        if (c.enabled === false)
            return;
        var s = DisplayModel.logicalSize(c);
        minX = Math.min(minX, c.x);
        minY = Math.min(minY, c.y);
        maxX = Math.max(maxX, c.x + s.w);
        maxY = Math.max(maxY, c.y + s.h);
        biggest = Math.max(biggest, s.w, s.h);
    });
    if (!isFinite(minX))
        return {
            "scale": 0.1,
            "ox": 0,
            "oy": 0
        };
    var room = biggest * 0.15;
    var worldW = (maxX - minX) + room * 2;
    var worldH = (maxY - minY) + room * 2;
    var scale = Math.max(Math.min(width / worldW, height / worldH), 0.001);
    return {
        "scale": scale,
        "ox": (width - (maxX - minX) * scale) / 2 - minX * scale,
        "oy": (height - (maxY - minY) * scale) / 2 - minY * scale
    };
}

// Live output of a config (by connector name), or null.
function outputFor(outputs, name) {
    for (var i = 0; i < outputs.length; i++) {
        if (outputs[i].name === name)
            return outputs[i];
    }
    return null;
}

// "Dell U2723QE" from make + model; the connector when neither is known.
function title(output, config) {
    var parts = [];
    if (output && output.make)
        parts.push(output.make);
    if (output && output.model)
        parts.push(output.model);
    return parts.length > 0 ? parts.join(" ") : config.name;
}

// Rotation selector options (Hyprland/niri transform 0-3)
function rotationOptions() {
    return ROTATIONS.map(function (t) {
        return {
            "value": t,
            "label": "prefs.displays.rotation." + t
        };
    });
}

// Variable refresh rate selector options (DisplayModel vrr: 0 off, 1 on, 2 fullscreen only)
function vrrOptions() {
    return [0, 1, 2].map(function (v) {
        return {
            "value": v,
            "label": "prefs.displays.vrr." + v
        };
    });
}
