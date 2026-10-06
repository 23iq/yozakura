.pragma library
.import "PanelStyles.js" as PanelStyles
.import "../BarModuleRegistry.js" as Modules

// Pure "panels" engine: turns bar.json into the list of panels each screen
// shows. Kept free of QML types so it is unit tested with node
// (tests/panel-layout.test.cjs).
//
// bar.panels: [ {
//     id         unique name ("main", "dock", ...)
//     edge       top | bottom | left | right
//     style      a PanelStyles.js id (classic, islands, menubar, ...)
//     groups     { start, center, end, drawer, gapStart, gapEnd }: module ids
//     align      fill | center | start | end   (dock-like styles: center)
//     size       module size in px, 0 = style default
//     thickness  panel thickness in px, 0 = sized by its content
//     margin     gap to the screen/frame edge in px, -1 = style default
//     flat       modules without their own pill background (null = style)
//     autohide   auto (follows the pin) | always (hover the edge) | never
//     reserve    reserve its space for windows (exclusive zone)
//     screens    [] = every screen; names, "primary", "secondary"
//     enabled    false keeps it in the config without showing it
//     options    free-form, style specific
// } ]
//
// An empty/missing `panels` list means the legacy single bar: bar.position +
// bar.layout + bar.screenList, rendered exactly as before.

var EDGES = ["top", "bottom", "left", "right"];
var GROUPS = PanelStyles.GROUPS;
var ALIGNS = ["fill", "center", "start", "end"];
var AUTOHIDE = ["auto", "always", "never"];

var DEFAULT_LAYOUT = {
    "style": "classic",
    "left": ["launcher", "workspaces", "layoutSelector", "pin"],
    "right": ["presets", "tools", "systray", "keyboardLayout", "controls", "battery", "clock", "power"],
    "drawer": []
};

// The untouched default layout on a vertical classic bar keeps its historical
// three-group arrangement (see BarLayout.js).
var LEGACY_VERTICAL = {
    "start": ["launcher", "systray", "tools", "presets"],
    "center": ["layoutSelector", "workspaces", "pin"],
    "end": ["keyboardLayout", "controls", "battery", "clock", "power"]
};

// JsonAdapter hands JSON arrays over as list wrappers (QVariantList), for
// which Array.isArray() is false. Accept any array-like.
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

function isObject(value) {
    return value !== null && typeof value === "object" && toArray(value) === null;
}

function sameList(a, b) {
    if (!a || !b || a.length !== b.length)
        return false;
    for (var i = 0; i < a.length; i++) {
        if (a[i] !== b[i])
            return false;
    }
    return true;
}

function emptyGroups() {
    var g = {};
    for (var i = 0; i < GROUPS.length; i++)
        g[GROUPS[i]] = [];
    return g;
}

function pick(value, allowed, fallback) {
    return allowed.indexOf(value) !== -1 ? value : fallback;
}

function number(value, fallback, min) {
    var n = typeof value === "number" && isFinite(value) ? value : fallback;
    return min !== undefined ? Math.max(min, n) : n;
}

// One panel spec from user JSON. Never throws; problems go to `warnings`.
function normalizePanel(raw, index, warnings) {
    var src = isObject(raw) ? raw : {};
    var where = "bar.panels[" + index + "]";
    if (!isObject(raw))
        warnings.push(where + " must be an object, using a default panel");

    var style = src.style;
    if (!PanelStyles.has(style)) {
        if (style !== undefined)
            warnings.push(where + ": unknown style '" + style + "', using 'classic'");
        style = "classic";
    }
    var meta = PanelStyles.get(style);

    var edge = src.edge;
    if (EDGES.indexOf(edge) === -1) {
        if (edge !== undefined)
            warnings.push(where + ": unknown edge '" + edge + "', using '" + meta.edges[0] + "'");
        edge = meta.edges[0];
    } else if (meta.edges.indexOf(edge) === -1) {
        warnings.push(where + ": style '" + style + "' does not support edge '" + edge + "', using '" + meta.edges[0] + "'");
        edge = meta.edges[0];
    }

    var groups = emptyGroups();
    var seen = {};
    var rawGroups = isObject(src.groups) ? src.groups : {};
    for (var g = 0; g < GROUPS.length; g++) {
        var name = GROUPS[g];
        var list = rawGroups[name];
        if (list === undefined || list === null)
            continue;
        list = toArray(list);
        if (list === null) {
            warnings.push(where + ".groups." + name + " must be an array");
            continue;
        }
        for (var i = 0; i < list.length; i++) {
            var id = list[i];
            if (typeof id !== "string" || !Modules.has(id)) {
                warnings.push(where + ": unknown module '" + id + "' in " + name + ", skipped");
                continue;
            }
            if (seen[id]) {
                warnings.push(where + ": module '" + id + "' listed twice, keeping the first ('" + seen[id] + "')");
                continue;
            }
            seen[id] = name;
            groups[name].push(id);
        }
    }

    var autohide = src.autohide;
    if (autohide === true)
        autohide = "always";
    else if (autohide === false)
        autohide = "never";
    autohide = pick(autohide, AUTOHIDE, "auto");

    var screens = toArray(src.screens) || [];
    screens = screens.filter(function (s) {
        return typeof s === "string" && s.length > 0;
    });

    return {
        "id": typeof src.id === "string" && src.id.length > 0 ? src.id : "panel-" + (index + 1),
        "edge": edge,
        "style": style,
        "groups": groups,
        "align": pick(src.align, ALIGNS, meta.floating ? "center" : "fill"),
        "size": number(src.size, 0, 0),
        "thickness": number(src.thickness, 0, 0),
        "margin": number(src.margin, -1, -1),
        "flat": typeof src.flat === "boolean" ? src.flat : meta.flat,
        "autohide": autohide,
        "reserve": typeof src.reserve === "boolean" ? src.reserve : true,
        "screens": screens,
        "enabled": src.enabled !== false,
        "options": isObject(src.options) ? JSON.parse(JSON.stringify(src.options)) : {},
        "legacy": false
    };
}

// The single panel described by the legacy keys (bar.position/layout/screenList).
function fromLegacy(bar) {
    var b = isObject(bar) ? bar : {};
    var layout = isObject(b.layout) ? b.layout : {};
    var warnings = [];
    var spec = normalizePanel({
        "id": "main",
        "edge": EDGES.indexOf(b.position) !== -1 ? b.position : "top",
        "style": PanelStyles.has(layout.style) ? layout.style : "classic",
        "groups": {
            "start": layout.left !== undefined ? layout.left : DEFAULT_LAYOUT.left,
            "end": layout.right !== undefined ? layout.right : DEFAULT_LAYOUT.right,
            "drawer": layout.drawer !== undefined ? layout.drawer : DEFAULT_LAYOUT.drawer
        },
        "screens": b.screenList
    }, 0, warnings);
    // A legacy bar keeps whatever edge it had, even one its style would not pick
    if (EDGES.indexOf(b.position) !== -1)
        spec.edge = b.position;
    spec.legacy = true;
    return spec;
}

// {panels, warnings, legacy}: every configured panel (screen filter not applied).
function normalize(bar) {
    var b = isObject(bar) ? bar : {};
    var raw = toArray(b.panels);
    if (b.panels !== undefined && b.panels !== null && raw === null)
        return {
            "panels": [fromLegacy(b)],
            "warnings": ["bar.panels must be an array, using the legacy bar"],
            "legacy": true
        };
    if (!raw || raw.length === 0)
        return {
            "panels": [fromLegacy(b)],
            "warnings": [],
            "legacy": true
        };
    var warnings = [];
    var panels = [];
    var ids = {};
    for (var i = 0; i < raw.length; i++) {
        var p = normalizePanel(raw[i], i, warnings);
        if (ids[p.id]) {
            var base = p.id;
            var n = 2;
            while (ids[base + "-" + n])
                n++;
            warnings.push("bar.panels[" + i + "]: duplicate id '" + base + "', renamed to '" + base + "-" + n + "'");
            p.id = base + "-" + n;
        }
        ids[p.id] = true;
        panels.push(p);
    }
    return {
        "panels": panels,
        "warnings": warnings,
        "legacy": false
    };
}

// Whether a panel shows on a screen. `screenIndex` 0 is the primary screen.
function onScreen(panel, screenName, screenIndex) {
    if (!panel.enabled)
        return false;
    var list = panel.screens || [];
    if (list.length === 0)
        return true;
    for (var i = 0; i < list.length; i++) {
        var s = list[i];
        if (s === screenName)
            return true;
        if (s === "primary" && screenIndex === 0)
            return true;
        if (s === "secondary" && screenIndex > 0)
            return true;
    }
    return false;
}

function forScreen(panels, screenName, screenIndex) {
    return panels.filter(function (p) {
        return onScreen(p, screenName, screenIndex);
    });
}

// The panel the notch, live activities and legacy consumers pair with: the
// first one on the notch's edge, else the first one. -1 when there is none.
function primaryIndex(panels, notchEdge) {
    for (var i = 0; i < panels.length; i++) {
        if (panels[i].edge === notchEdge)
            return i;
    }
    return panels.length > 0 ? 0 : -1;
}

// Edge of the primary panel over every configured panel (screen-agnostic),
// used where only "the bar's edge" matters (desktop margins, overview...).
function primaryEdge(bar, notchEdge) {
    var all = normalize(bar).panels.filter(function (p) {
        return p.enabled;
    });
    var i = primaryIndex(all, notchEdge);
    return i === -1 ? (EDGES.indexOf(bar && bar.position) !== -1 ? bar.position : "top") : all[i].edge;
}

function orientationOf(edge) {
    return edge === "left" || edge === "right" ? "vertical" : "horizontal";
}

// Default right group before the keyboard layout indicator existed: a panel
// still holding it is the untouched default and gets the indicator.
var OLD_DEFAULT_RIGHT = ["presets", "tools", "systray", "controls", "battery", "clock", "power"];

function upgradeOldDefault(panel) {
    var g = panel.groups;
    if (sameList(g.start, DEFAULT_LAYOUT.left) && sameList(g.end, OLD_DEFAULT_RIGHT) && g.drawer.length === 0 && g.center.length === 0) {
        var groups = {};
        for (var k in g)
            groups[k] = g[k];
        groups.end = DEFAULT_LAYOUT.right.slice();
        var out = {};
        for (var p in panel)
            out[p] = panel[p];
        out.groups = groups;
        return out;
    }
    return panel;
}

function isDefaultArrangement(panel) {
    var g = panel.groups;
    return sameList(g.start, DEFAULT_LAYOUT.left) && sameList(g.end, DEFAULT_LAYOUT.right) && g.drawer.length === 0 && g.center.length === 0;
}

// Groups in render order. The untouched default layout on a vertical
// classic panel keeps its historical three-group arrangement.
function resolveGroups(panel) {
    panel = upgradeOldDefault(panel);
    var g = panel.groups;
    if (orientationOf(panel.edge) === "vertical" && panel.style === "classic" && isDefaultArrangement(panel)) {
        var out = emptyGroups();
        out.start = LEGACY_VERTICAL.start.slice();
        out.center = LEGACY_VERTICAL.center.slice();
        out.end = LEGACY_VERTICAL.end.slice();
        return out;
    }
    var copy = emptyGroups();
    for (var i = 0; i < GROUPS.length; i++)
        copy[GROUPS[i]] = (g[GROUPS[i]] || []).slice();
    return copy;
}

// Space each edge reserves for windows. `entries`: [{edge, size, reserving}]
// where size is the panel's full depth from the screen edge (thickness +
// margins + contained frame). Panels on one edge overlap, so the deepest wins.
function edgeZones(entries) {
    var z = {
        "top": 0,
        "bottom": 0,
        "left": 0,
        "right": 0
    };
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (!e || !e.reserving || z[e.edge] === undefined)
            continue;
        z[e.edge] = Math.max(z[e.edge], Math.max(0, Math.round(e.size || 0)));
    }
    return z;
}

// Whether a panel reserves its space right now.
function reserves(panel, pinned) {
    if (!panel.reserve)
        return false;
    if (panel.autohide === "never")
        return true;
    if (panel.autohide === "always")
        return true;
    return pinned;
}

// A JSON-ready copy of `panels` for writing back to bar.json (drops the
// computed `legacy` flag and default-valued fields stay explicit).
function serialize(panels) {
    return panels.map(function (p) {
        var groups = {};
        for (var i = 0; i < GROUPS.length; i++) {
            var list = p.groups && p.groups[GROUPS[i]] ? toArray(p.groups[GROUPS[i]]) : [];
            if (list.length > 0)
                groups[GROUPS[i]] = list.slice();
        }
        var out = {
            "id": p.id,
            "edge": p.edge,
            "style": p.style,
            "groups": groups
        };
        var keys = ["align", "size", "thickness", "margin", "flat", "autohide", "reserve", "screens", "enabled", "options"];
        for (var k = 0; k < keys.length; k++) {
            if (p[keys[k]] !== undefined)
                out[keys[k]] = JSON.parse(JSON.stringify(p[keys[k]]));
        }
        return out;
    });
}
