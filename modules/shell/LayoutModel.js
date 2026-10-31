.pragma library
.import "../bar/panels/PanelLayout.js" as PanelLayout
.import "../bar/panels/PanelStyles.js" as PanelStyles
.import "../bar/panels/PanelEdit.js" as PanelEdit

// The composable layout: three independent parts (bar, notch, dock), each
// { enabled, edge, style, align }, read from the existing keys only:
//   bar    bar.panels (the primary panel), else the legacy bar.position +
//          bar.layout.style ("none" = off)
//   notch  notch.enabled, notch.position, notch.style, notch.align
//   dock   dock.enabled, dock.position, dock.theme (no align: centered)
// Disabling a part re-homes its content (homeOf): notch activities go to
// the bar, or to corner pills when the bar is off too; the bar's clock and
// tray go to the notch (or to the corner pills). The idle island's own
// media, notification bell and muted microphone go to the bar module of
// the same id (BAR_MODULES) while the notch is off, else to the corner
// pills; while the notch shows them that bar module stays hidden, so
// nothing shows twice. Pure, tested in tests/layout-model.test.cjs.

var PARTS = ["bar", "dock", "notch"]; // also the stacking order, edge inward
var CONTENT = ["activities", "clock", "tray", "media", "notifications", "mic"];
// Content the bar shows only through its own bar module (BarModuleRegistry)
var BAR_MODULES = ["media", "notifications", "mic"];
// What the idle notch shows of its own (never one of its extra segments)
var NOTCH_OWN = ["activities", "media", "notifications", "mic"];
var EDGES = PanelLayout.EDGES;
// The notch runs upright on the side edges (NotchPlacement, NotchShape.js)
var NOTCH_EDGES = EDGES.slice();
// The dock window has no top edge (DockContent)
var DOCK_EDGES = ["bottom", "left", "right"];
var ALIGNS = ["start", "center", "end"];
var NOTCH_STYLES = ["attached", "island", "pill"];
var DOCK_STYLES = ["default", "floating", "integrated"];

// Where each content id lives, by preference.
var HOMES = {
    "activities": ["notch", "bar"],
    "clock": ["bar", "notch"],
    "tray": ["bar", "notch"],
    "media": ["notch", "bar"],
    "notifications": ["notch", "bar"],
    "mic": ["notch", "bar"]
};

function _obj(v) {
    return v !== null && typeof v === "object" ? v : {};
}

function _pick(v, list, fallback) {
    return list.indexOf(v) !== -1 ? v : fallback;
}

function _primary(panels) {
    for (var i = 0; i < panels.length; i++)
        if (panels[i].enabled)
            return i;
    return 0;
}

function _bar(bar) {
    var n = PanelLayout.normalize(bar);
    var panels = n.panels;
    var p = panels[_primary(panels)] || {};
    var on = panels.some(function (x) {
        return x.enabled;
    });
    var style = n.legacy ? _obj(_obj(bar).layout).style : p.style;
    var modules = [];
    panels.forEach(function (x) {
        var g = _obj(x.groups);
        Object.keys(g).forEach(function (k) {
            (x.enabled ? g[k] || [] : []).forEach(function (id) {
                if (modules.indexOf(id) === -1)
                    modules.push(id);
            });
        });
    });
    return {
        "enabled": on,
        "edge": p.edge || "top",
        // Edges holding an enabled panel (the notch may share any of them)
        "edges": panels.filter(function (x) {
            return x.enabled;
        }).map(function (x) {
            return x.edge;
        }),
        "style": PanelStyles.has(style) && !PanelStyles.isHidden(style) ? style : "classic",
        "align": p.align || "fill",
        // Module ids placed on the enabled panels, in panel order
        "modules": modules
    };
}

// {bar, notch, dock} of a {bar, notch, dock} config (Config.bar, ...).
function fromConfig(cfg) {
    var c = _obj(cfg);
    var notch = _obj(c.notch);
    var dock = _obj(c.dock);
    return {
        "bar": _bar(c.bar),
        "notch": {
            "enabled": notch.enabled !== false,
            "edge": _pick(notch.position, EDGES, "top"),
            "style": _pick(notch.style, NOTCH_STYLES, "attached"),
            "align": _pick(notch.align, ALIGNS, "center")
        },
        "dock": {
            "enabled": dock.enabled !== false,
            "edge": _pick(dock.position, DOCK_EDGES, "bottom"),
            "style": _pick(dock.theme, DOCK_STYLES, "default"),
            "align": "center"
        }
    };
}

function _on(layout, part) {
    return !!(layout && layout[part] && layout[part].enabled);
}

// `part` can show `contentId`: it is on and, for the bar, holds the
// content's own module when it needs one (BAR_MODULES)
function _holds(layout, part, contentId) {
    if (!_on(layout, part))
        return false;
    if (part !== "bar" || BAR_MODULES.indexOf(contentId) === -1)
        return true;
    return (layout.bar.modules || []).indexOf(contentId) !== -1;
}

// The part showing `contentId` ("bar" | "notch" | "corner"), "" if unknown.
function homeOf(contentId, layout) {
    var prefs = HOMES[contentId];
    if (!prefs)
        return "";
    for (var i = 0; i < prefs.length; i++)
        if (_holds(layout, prefs[i], contentId))
            return prefs[i];
    return "corner";
}

function _homedIn(layout, home) {
    return CONTENT.filter(function (id) {
        return homeOf(id, layout) === home;
    });
}

// Content the notch shows besides its own (NOTCH_OWN).
function notchSegments(layout) {
    return _homedIn(layout, "notch").filter(function (id) {
        return NOTCH_OWN.indexOf(id) === -1;
    });
}

// Live activities sit next to a horizontal bar's middle (islands); a
// vertical bar has no room for them, so they go to the corner pills.
function _barHoldsActivities(layout) {
    var e = layout.bar.edge;
    return e === "top" || e === "bottom";
}

function cornerContent(layout) {
    var out = _homedIn(layout, "corner");
    if (homeOf("activities", layout) === "bar" && !_barHoldsActivities(layout))
        out.unshift("activities");
    return out;
}

// A bar panel sits on the notch's edge (the notch would grow over it)
function barSharesNotchEdge(layout) {
    if (!_on(layout, "bar") || !_on(layout, "notch"))
        return false;
    var edges = layout.bar.edges || [layout.bar.edge];
    return edges.indexOf(layout.notch.edge) !== -1;
}

// Effective bar.activities.presentation: "off" stays off; a notch home
// keeps the configured one, a bar home is "islands", else "corner".
// `placeIn` (notch.activitiesIn): "auto" (default) turns the notch's own
// activities into bar chips ("bar") while a bar shares the notch's edge,
// "bar" whenever a bar is on, "notch" never.
function activityPresentation(layout, configured, placeIn) {
    if (configured === "off")
        return "off";
    var home = homeOf("activities", layout);
    if (home === "notch") {
        if (configured === "islands")
            return "islands";
        var where = placeIn === "notch" || placeIn === "bar" ? placeIn : "auto";
        if (where === "bar" ? _on(layout, "bar") : where === "auto" && barSharesNotchEdge(layout))
            return "bar";
        return "notch";
    }
    return home === "bar" && _barHoldsActivities(layout) ? "islands" : "corner";
}

// Enabled parts per edge, outermost first.
function stacking(layout) {
    var out = {};
    EDGES.forEach(function (e) {
        out[e] = [];
    });
    PARTS.forEach(function (p) {
        if (_on(layout, p) && out[layout[p].edge])
            out[layout[p].edge].push(p);
    });
    return out;
}

// Index of `part` on its edge (0 = against the screen edge), -1 when off.
function depthOf(part, layout) {
    if (!_on(layout, part))
        return -1;
    return stacking(layout)[layout[part].edge].indexOf(part);
}

function edgesOf(part) {
    if (part === "notch")
        return NOTCH_EDGES.slice();
    if (part === "dock")
        return DOCK_EDGES.slice();
    return PARTS.indexOf(part) === -1 ? [] : EDGES.slice();
}

function stylesOf(part) {
    if (part === "bar")
        return PanelStyles.BAR_STYLES.filter(function (s) {
            return !PanelStyles.isHidden(s);
        });
    if (part === "notch")
        return NOTCH_STYLES.slice();
    return part === "dock" ? DOCK_STYLES.slice() : [];
}

function alignsOf(part) {
    if (part === "bar")
        return PanelLayout.ALIGNS.slice();
    return part === "notch" ? ALIGNS.slice() : [];
}

function canDrop(part, edge) {
    return edgesOf(part).indexOf(edge) !== -1;
}

function _valid(part, field, value) {
    if (field === "enabled")
        return typeof value === "boolean";
    if (field === "edge")
        return canDrop(part, value);
    if (field === "style")
        return stylesOf(part).indexOf(value) !== -1;
    if (field === "align")
        return alignsOf(part).indexOf(value) !== -1;
    return false;
}

var _KEYS = {
    "notch": { "enabled": "notch.enabled", "edge": "notch.position", "style": "notch.style", "align": "notch.align" },
    "dock": { "enabled": "dock.enabled", "edge": "dock.position", "style": "dock.theme" }
};

// `memory` ({enabled: {panelId: bool}}) is what the bar had before it was
// switched off (see remember): turning it on gives each panel back its own
// flag; without it every panel with a visible style comes on.
function _panelEdit(panels, field, value, memory) {
    var out = JSON.parse(JSON.stringify(panels));
    var i = _primary(out);
    if (field === "enabled") {
        var was = _obj(_obj(memory).enabled);
        out.forEach(function (p) {
            p.enabled = value && !PanelStyles.isHidden(p.style) && (was[p.id] !== false);
        });
        if (value && !out.some(function (p) {
            return p.enabled;
        })) {
            // Nothing to give back: bring up the first panel, in its own
            // style when it has a visible one
            out[0].enabled = true;
            if (PanelStyles.isHidden(out[0].style))
                out[0].style = "classic";
        }
        return PanelLayout.serialize(out);
    }
    out[i] = PanelEdit.apply(out[i], field, value);
    return PanelLayout.serialize(out);
}

function _barEdit(bar, field, value, memory) {
    var n = PanelLayout.normalize(bar);
    if (n.legacy && field !== "align") {
        // Same pairing rules as the panels (PanelEdit)
        var curStyle = n.panels[0].style;
        if (field === "edge") {
            var edgeWrites = [{ "key": "bar.position", "value": value }];
            if (!PanelStyles.supportsEdge(curStyle, value))
                edgeWrites.push({ "key": "bar.layout.style", "value": "classic" });
            return edgeWrites;
        }
        if (field === "style") {
            var styleWrites = [{ "key": "bar.layout.style", "value": value }];
            if (!PanelStyles.supportsEdge(value, n.panels[0].edge))
                styleWrites.push({ "key": "bar.position", "value": PanelStyles.get(value).edges[0] });
            return styleWrites;
        }
        var cur = _obj(_obj(bar).layout).style;
        if (!value)
            return [{ "key": "bar.layout.style", "value": "none" }];
        if (!PanelStyles.isHidden(cur))
            return [];
        var back = _obj(memory).style;
        var restored = PanelStyles.has(back) && !PanelStyles.isHidden(back) ? back : "classic";
        return [{ "key": "bar.layout.style", "value": restored }];
    }
    // Panels (an align edit turns the legacy bar into bar.panels, the same
    // way the panels editor does on its first edit)
    return [{ "key": "bar.panels", "value": _panelEdit(n.panels, field, value, memory) }];
}

// What to remember before `part`'s `enabled` is set to false, so that
// edit(..., memory) can bring the bar back exactly as it was: {style} for
// the legacy bar, {enabled: {panelId: bool}} for panels. undefined when
// there is nothing to remember (not the bar, not an off edit, or the bar
// is already off: a repeated off must not overwrite what was saved).
function remember(cfg, part, field, value) {
    if (part !== "bar" || field !== "enabled" || value !== false)
        return undefined;
    var bar = _obj(cfg).bar;
    var n = PanelLayout.normalize(bar);
    if (!n.panels.some(function (p) {
        return p.enabled;
    }))
        return undefined;
    if (n.legacy)
        return { "style": n.panels[0].style };
    var enabled = {};
    n.panels.forEach(function (p) {
        enabled[p.id] = p.enabled;
    });
    return { "enabled": enabled };
}

// The config writes ([{key, value}]) that set `field` (enabled | edge |
// style | align) of `part`; [] when the value is not allowed. `memory` is
// what remember() returned when the bar was switched off.
function edit(cfg, part, field, value, memory) {
    if (!_valid(part, field, value))
        return [];
    if (part === "bar")
        return _barEdit(_obj(cfg).bar, field, value, memory);
    var key = _KEYS[part] ? _KEYS[part][field] : undefined;
    return key ? [{ "key": key, "value": value }] : [];
}
