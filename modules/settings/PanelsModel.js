.pragma library
.import "../bar/panels/PanelLayout.js" as PanelLayout
.import "../bar/panels/PanelStyles.js" as PanelStyles
.import "../bar/BarModuleRegistry.js" as Modules

// Pure edit operations of the panels editor (editors/PanelsEditor.qml).
// Every function returns a new list ready for SettingsStore.set("bar.panels",
// ...); the first edit of a legacy single bar turns it into bar.panels.
// Tested in tests/panels-model.test.cjs.

var GROUP_TITLES = {
    "start": "prefs.bar.group.start",
    "center": "prefs.bar.group.center",
    "end": "prefs.bar.group.end",
    "drawer": "prefs.bar.group.drawer",
    "gapStart": "prefs.bar.group.gap_start",
    "gapEnd": "prefs.bar.group.gap_end"
};

var GROUP_ICONS = {
    "start": "alignLeft",
    "center": "alignCenter",
    "end": "alignRight",
    "drawer": "caretDoubleLeft",
    "gapStart": "caretLineLeft",
    "gapEnd": "caretLineRight"
};

// Normalized panels of a bar config (the legacy bar when none is listed).
function panelsOf(bar) {
    return PanelLayout.normalize(bar).panels;
}

function isLegacy(bar) {
    return PanelLayout.normalize(bar).legacy;
}

function serialize(panels) {
    return PanelLayout.serialize(panels);
}

function clone(v) {
    return JSON.parse(JSON.stringify(v));
}

function uniqueId(panels, base) {
    var taken = {};
    panels.forEach(function (p) {
        taken[p.id] = true;
    });
    if (!taken[base])
        return base;
    var n = 2;
    while (taken[base + "-" + n])
        n++;
    return base + "-" + n;
}

// A new panel on the first edge no panel uses yet, with a useful default
// per style.
function addPanel(panels, style) {
    var used = panels.map(function (p) {
        return p.edge;
    });
    var meta = PanelStyles.get(style || "classic");
    var edge = meta.edges.filter(function (e) {
        return used.indexOf(e) === -1;
    })[0] || meta.edges[0];
    var groups = {
        "start": [],
        "center": [],
        "end": ["clock"]
    };
    if (meta.id === "dock")
        groups = {
            "start": [],
            "center": ["taskbar"],
            "end": []
        };
    var raw = {
        "id": uniqueId(panels, meta.id === "dock" ? "dock" : "panel"),
        "edge": edge,
        "style": meta.id,
        "groups": groups
    };
    return serialize(panels.concat([PanelLayout.normalizePanel(raw, panels.length, [])]));
}

function removePanel(panels, index) {
    return serialize(panels.filter(function (p, i) {
        return i !== index;
    }));
}

// Set one field of one panel; edge/style changes keep the pair valid.
function setField(panels, index, field, value) {
    var out = clone(panels);
    var p = out[index];
    if (!p)
        return serialize(out);
    p[field] = value;
    if (field === "style" && !PanelStyles.supportsEdge(value, p.edge))
        p.edge = PanelStyles.get(value).edges[0];
    if (field === "style")
        p.flat = PanelStyles.get(value).flat;
    if (field === "edge" && !PanelStyles.supportsEdge(p.style, value)) {
        var fallback = ["classic", "islands"].indexOf(p.style) === -1 ? "classic" : p.style;
        p.style = PanelStyles.supportsEdge(fallback, value) ? fallback : "classic";
    }
    return serialize(out);
}

// Groups the panel's style renders, in editor order.
function groupsOf(panel) {
    return PanelStyles.get(panel.style).groups.slice();
}

// Modules not placed anywhere on this panel.
function unused(panel) {
    var used = [];
    PanelStyles.GROUPS.forEach(function (g) {
        used = used.concat(panel.groups[g] || []);
    });
    return Modules.ids().filter(function (id) {
        return used.indexOf(id) === -1;
    });
}

// Move module `id` of panel `index` to `group` at `at` ("available" removes it).
function moveModule(panels, index, id, group, at) {
    var out = clone(panels);
    var p = out[index];
    if (!p)
        return serialize(out);
    PanelStyles.GROUPS.forEach(function (g) {
        p.groups[g] = (p.groups[g] || []).filter(function (x) {
            return x !== id;
        });
    });
    if (PanelStyles.GROUPS.indexOf(group) !== -1) {
        var list = p.groups[group];
        var i = Math.max(0, Math.min(at === undefined || at < 0 ? list.length : at, list.length));
        list.splice(i, 0, id);
    }
    return serialize(out);
}

// {group, index} of `id` on the panel; "available" when unused.
function locate(panel, id) {
    for (var g = 0; g < PanelStyles.GROUPS.length; g++) {
        var name = PanelStyles.GROUPS[g];
        var i = (panel.groups[name] || []).indexOf(id);
        if (i !== -1)
            return {
                "group": name,
                "index": i
            };
    }
    return {
        "group": "available",
        "index": unused(panel).indexOf(id)
    };
}
