.pragma library
.import "../bar/panels/PanelLayout.js" as PanelLayout
.import "../bar/panels/PanelStyles.js" as PanelStyles

// The composable layout: three independent parts (bar, notch, dock), each
// { enabled, edge, style, align }, read from the existing keys only:
//   bar    bar.panels (the primary panel), else the legacy bar.position +
//          bar.layout.style ("none" = off)
//   notch  notch.enabled, notch.position, notch.style, notch.align
//   dock   dock.enabled, dock.position, dock.theme (no align: centered)
// Disabling a part re-homes its content (homeOf): notch activities go to
// the bar, or to corner pills when the bar is off too; the bar's clock and
// tray go to the notch (or to the corner pills). Pure, tested in
// tests/layout-model.test.cjs.

var PARTS = ["bar", "dock", "notch"]; // also the stacking order, edge inward
var CONTENT = ["activities", "clock", "tray"];
var EDGES = PanelLayout.EDGES;
// The notch runs upright on the side edges (NotchPlacement, NotchShape.js)
var NOTCH_EDGES = EDGES.slice();
var ALIGNS = ["start", "center", "end"];
var NOTCH_STYLES = ["attached", "island", "pill"];
var DOCK_STYLES = ["default", "floating", "integrated"];

// Where each content id lives, by preference.
var HOMES = {
    "activities": ["notch", "bar"],
    "clock": ["bar", "notch"],
    "tray": ["bar", "notch"]
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
        "align": p.align || "fill"
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
            "edge": _pick(dock.position, EDGES, "bottom"),
            "style": _pick(dock.theme, DOCK_STYLES, "default"),
            "align": "center"
        }
    };
}

function _on(layout, part) {
    return !!(layout && layout[part] && layout[part].enabled);
}

// The part showing `contentId` ("bar" | "notch" | "corner"), "" if unknown.
function homeOf(contentId, layout) {
    var prefs = HOMES[contentId];
    if (!prefs)
        return "";
    for (var i = 0; i < prefs.length; i++)
        if (_on(layout, prefs[i]))
            return prefs[i];
    return "corner";
}

function _homedIn(layout, home) {
    return CONTENT.filter(function (id) {
        return homeOf(id, layout) === home;
    });
}

// Content the notch shows besides its own (activities are its own).
function notchSegments(layout) {
    return _homedIn(layout, "notch").filter(function (id) {
        return id !== "activities";
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

function _panelEdit(panels, field, value) {
    var out = JSON.parse(JSON.stringify(panels));
    var i = _primary(out);
    if (field === "enabled") {
        out.forEach(function (p) {
            p.enabled = value && !PanelStyles.isHidden(p.style);
        });
        if (value && !out.some(function (p) {
            return p.enabled;
        })) {
            out[0].enabled = true;
            out[0].style = "classic";
        }
        return PanelLayout.serialize(out);
    }
    var p = out[i];
    p[field] = value;
    if (field === "style" && !PanelStyles.supportsEdge(value, p.edge))
        p.edge = PanelStyles.get(value).edges[0];
    if (field === "edge" && !PanelStyles.supportsEdge(p.style, value))
        p.style = "classic";
    return PanelLayout.serialize(out);
}

function _barEdit(bar, field, value) {
    var n = PanelLayout.normalize(bar);
    if (n.legacy && field !== "align") {
        if (field === "edge")
            return [{ "key": "bar.position", "value": value }];
        if (field === "style")
            return [{ "key": "bar.layout.style", "value": value }];
        var cur = _obj(_obj(bar).layout).style;
        if (!value)
            return [{ "key": "bar.layout.style", "value": "none" }];
        return PanelStyles.isHidden(cur) ? [{ "key": "bar.layout.style", "value": "classic" }] : [];
    }
    // Panels (an align edit turns the legacy bar into bar.panels, the same
    // way the panels editor does on its first edit)
    return [{ "key": "bar.panels", "value": _panelEdit(n.panels, field, value) }];
}

// The config writes ([{key, value}]) that set `field` (enabled | edge |
// style | align) of `part`; [] when the value is not allowed.
function edit(cfg, part, field, value) {
    if (!_valid(part, field, value))
        return [];
    if (part === "bar")
        return _barEdit(_obj(cfg).bar, field, value);
    var key = _KEYS[part] ? _KEYS[part][field] : undefined;
    return key ? [{ "key": key, "value": value }] : [];
}
