.pragma library

// Pure helpers of the fastfetch greeting UI (Settings > Terminal, the
// onboarding terminal step): preview cache keys, which choices apply, what
// the notices say and the terminal's 16 colours for the preview.
// Node-tested (tests/term-fetch-model.test.cjs).

var OWN = "own";

// The logo choices (terminal.fastfetchLogo), in chip order.
function logos() {
    return ["distro", "sakura", "custom", "none"];
}

// Cache key of a `term.fetch.preview` result.
function previewKey(preset, logo, path) {
    return String(preset || "") + "|" + String(logo || "") + "|" + (logo === "custom" ? String(path || "") : "");
}

// The preset entry ({id, logo, own}) of id, or null.
function presetOf(presets, id) {
    var list = presets || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === id)
            return list[i];
    }
    return null;
}

// "" when the logo choice applies to the preset, else why not:
// "own" (your fastfetch config decides) or "none" (the look has no logo).
function logoBlocked(preset) {
    if (!preset)
        return "";
    if (preset.own)
        return "own";
    return preset.logo ? "" : "none";
}

// The look the switch turns on with: "own" without a fastfetch config of
// the user's would be plain fastfetch, so the sakura look is used instead.
function presetOnTurnOn(current, ownConfig) {
    return current === OWN && !ownConfig ? "sakura" : (current || "sakura");
}

// The shells the greeting runs in now (["fish", "bash"]).
function shellsOn(greeting) {
    return ((greeting && greeting.shells) || []).filter(function (s) {
        return s && s.state === "on";
    }).map(function (s) {
        return s.shell;
    });
}

// Shells in a state ("foreign", "managed"): [{shell, file}].
function shellsIn(greeting, state) {
    return ((greeting && greeting.shells) || []).filter(function (s) {
        return s && s.state === state;
    });
}

// "~/.bashrc" for a path in home.
function tilde(path, home) {
    var p = String(path || "");
    var h = String(home || "");
    return h !== "" && p.indexOf(h + "/") === 0 ? "~" + p.substring(h.length) : p;
}

// The translation key of a custom logo problem ("" none).
function logoErrorKey(greeting) {
    var e = greeting ? String(greeting.logoError || "") : "";
    return /^logo_[a-z_]+$/.test(e) ? "prefs.term.fetch.logo_error." + e : (e !== "" ? "prefs.term.fetch.logo_error.logo_format" : "");
}

// Why the preview is a sample ("" when it is fastfetch's real output).
function sampleReason(preview) {
    if (!preview || preview.exact)
        return "";
    return preview.reason === "fastfetch_missing" ? "missing" : "failed";
}

function _hex(c) {
    if (c === undefined || c === null)
        return "";
    if (typeof c === "string")
        return /^#[0-9a-fA-F]{6}$/.test(c) ? c.toLowerCase() : (/^#[0-9a-fA-F]{8}$/.test(c) ? ("#" + c.substring(3)).toLowerCase() : "");
    var h = function (v) {
        var s = Math.round(Math.max(0, Math.min(1, Number(v) || 0)) * 255).toString(16);
        return s.length < 2 ? "0" + s : s;
    };
    return "#" + h(c.r) + h(c.g) + h(c.b);
}

// The terminal's 16 colours as the kitty theme sets them
// (modules/theme/KittyGenerator.qml), from the Colors singleton: the
// preview draws ANSI colours (distribution logos) the way kitty will.
// Returns [] when a colour is missing.
var ANSI_ROLES = [["surfaceContainerHigh", "overSurface"], "red", "green", "yellow", "blue", "magenta", "cyan", ["overSurfaceVariant", "surfaceContainerHigh"], "outline", "lightRed", "lightGreen", "lightYellow", "lightBlue", "lightMagenta", "lightCyan", ["overSurface", "surfaceContainerLowest"]];

function ansiTable(colors, dark) {
    var out = [];
    for (var i = 0; i < ANSI_ROLES.length; i++) {
        var r = ANSI_ROLES[i];
        var name = typeof r === "string" ? r : (dark ? r[0] : r[1]);
        var hex = _hex(colors ? colors[name] : undefined);
        if (hex === "")
            return [];
        out.push(hex);
    }
    return out;
}
