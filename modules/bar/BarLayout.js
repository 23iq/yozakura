.pragma library
.import "BarModuleRegistry.js" as Modules
.import "panels/PanelStyles.js" as PanelStyles

// Pure helpers for the legacy single-bar layout (bar.json "layout" key).
// Multi-panel configs (bar.panels) go through panels/PanelLayout.js.
// Kept free of QML types so it can be unit tested with node.

// Every module id the bar knows how to build (BarModuleRegistry.js).
var MODULE_IDS = Modules.ids();

// Every panel style (panels/PanelStyles.js).
var STYLES = PanelStyles.ids();

// Mirrors config/defaults/bar.js so a missing/invalid key still renders the
// historical bar. The test suite asserts both stay in sync.
var DEFAULT_LAYOUT = {
    "style": "classic",
    "left": ["launcher", "workspaces", "layoutSelector", "pin"],
    "right": ["presets", "tools", "systray", "keyboardLayout", "controls", "battery", "clock", "power"],
    "drawer": []
};

function isKnown(id) {
    return MODULE_IDS.indexOf(id) !== -1;
}

// JsonAdapter hands JSON arrays to JS as list wrappers (QVariantList), for
// which Array.isArray() is false. Accept any array-like, not just Array.
function toArray(value) {
    if (Array.isArray(value))
        return value;
    if (value && typeof value === "object" && typeof value.length === "number") {
        var out = [];
        for (var i = 0; i < value.length; i++)
            out.push(value[i]);
        return out;
    }
    return null;
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

// Returns {style, left, right, drawer, warnings}. Never throws: unknown ids,
// duplicates and wrong types are dropped and reported in `warnings`.
function normalize(raw, defaults) {
    var base = defaults || DEFAULT_LAYOUT;
    var warnings = [];
    var src = (raw && typeof raw === "object" && toArray(raw) === null) ? raw : {};
    if (raw !== undefined && raw !== null && src !== raw)
        warnings.push("bar.layout must be an object, using defaults");

    var style = src.style;
    if (STYLES.indexOf(style) === -1) {
        if (style !== undefined)
            warnings.push("unknown bar.layout.style '" + style + "', using '" + base.style + "'");
        style = STYLES.indexOf(base.style) !== -1 ? base.style : "classic";
    }

    var seen = {};
    function group(name, fallback) {
        var list = src[name];
        if (list === undefined || list === null) {
            list = fallback;
        } else if (toArray(list) === null) {
            warnings.push("bar.layout." + name + " must be an array, using defaults");
            list = fallback;
        } else {
            list = toArray(list);
        }
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var id = list[i];
            if (typeof id !== "string" || !isKnown(id)) {
                warnings.push("unknown bar module '" + id + "' in bar.layout." + name + ", skipped");
                continue;
            }
            if (seen[id]) {
                warnings.push("bar module '" + id + "' listed twice, keeping the first ('" + seen[id] + "')");
                continue;
            }
            seen[id] = name;
            out.push(id);
        }
        return out;
    }

    var left = group("left", base.left || []);
    var right = group("right", base.right || []);
    var drawer = group("drawer", base.drawer || []);

    return {
        "style": style,
        "left": left,
        "right": right,
        "drawer": drawer,
        "warnings": warnings
    };
}

// Modules whose visibility is decided by a config flag are removed up front
// so that radius continuity is computed over what is actually shown.
function visibleIds(ids, opts) {
    var showPin = !opts || opts.showPinButton === undefined ? true : opts.showPinButton;
    return ids.filter(function (id) {
        return id !== "pin" || showPin;
    });
}

// End group ids with the live activity chips ("activities") first, when
// the panel hosts them (`on`) and no group of `groups` places them already.
function withActivityChips(endIds, groups, on) {
    var ids = endIds || [];
    if (!on)
        return ids;
    var g = groups || {};
    for (var k in g)
        if (Array.isArray(g[k]) && g[k].indexOf("activities") !== -1)
            return ids;
    return ["activities"].concat(ids);
}

// Pill continuity: the first item of a group gets the outer radius on its
// start edge, the last on its end edge, everything else the inner radius.
// A connected edge (dock or drawer attached) keeps the inner radius.
function edgeRadii(index, count, outer, inner, startConnected, endConnected) {
    var first = index === 0;
    var last = index === count - 1;
    return {
        "start": first && !startConnected ? outer : inner,
        "end": last && !endConnected ? outer : inner
    };
}

// ids with a "__sep__" marker between consecutive modules (strip styles)
function withSeparators(ids) {
    var out = [];
    for (var i = 0; i < ids.length; i++) {
        if (i > 0)
            out.push("__sep__");
        out.push(ids[i]);
    }
    return out;
}
