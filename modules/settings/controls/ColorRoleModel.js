.pragma library
.import "../../../config/ColorSpec.js" as ColorSpec

// Pure model of the `color-role` control (ColorRoleControl.qml): a value is
// one color spec ("primary", "surfaceBright@0.6", "#ff0000") or a list of
// them (gradient stops). Node-tested (tests/color-role.test.cjs).

// Palette roles offered as swatches (any role or literal still round-trips).
var ROLES = ["primary", "primaryContainer", "inversePrimary", "secondary", "secondaryContainer", "tertiary", "tertiaryContainer", "error", "surface", "surfaceBright", "surfaceContainerLow", "surfaceContainerHigh", "surfaceVariant", "outline", "outlineVariant", "overBackground", "shadow", "red", "yellow", "green", "cyan", "blue", "magenta", "white"];

var MAX_STOPS = 4;

function toStops(value) {
    if (value === undefined || value === null || value === "")
        return [];
    if (typeof value === "string")
        return [value];
    var out = [];
    for (var i = 0; i < value.length; i++) {
        if (typeof value[i] === "string" && value[i] !== "")
            out.push(value[i]);
    }
    return out;
}

// Back to the stored shape: a list for gradient keys, a string otherwise.
function fromStops(stops, gradient) {
    return gradient ? stops.slice() : (stops[0] || "");
}

function roleOf(spec) {
    return ColorSpec.baseOf(spec);
}

function alphaOf(spec) {
    return ColorSpec.alphaOf(spec);
}

function setRole(stops, i, role) {
    var out = stops.slice();
    out[i] = ColorSpec.compose(role, alphaOf(stops[i] || role));
    return out;
}

function setAlpha(stops, i, a) {
    var out = stops.slice();
    out[i] = ColorSpec.compose(roleOf(stops[i]), Math.round(Math.max(0, Math.min(1, a)) * 100) / 100);
    return out;
}

// Inserts a copy of stop i after it.
function addStop(stops, i, max) {
    if (stops.length >= (max || MAX_STOPS))
        return stops.slice();
    var out = stops.slice();
    out.splice(i + 1, 0, stops[i] || "primary");
    return out;
}

function removeStop(stops, i) {
    if (stops.length <= 1)
        return stops.slice();
    var out = stops.slice();
    out.splice(i, 1);
    return out;
}
