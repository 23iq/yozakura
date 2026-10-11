.pragma library
.import "PanelStyles.js" as PanelStyles

// The one place that decides what changing a panel's edge, style or align
// does to the rest of the panel, shared by the panels editor
// (settings/PanelsModel.js) and the composable layout (shell/LayoutModel.js).
// Pure, tested in tests/panel-edit.test.cjs.
//
// Rules:
//   - a style the new edge does not support keeps the edge only when the
//     style was picked: the edge then moves to the style's natural one;
//   - an edge the style does not support moves the style to "classic"
//     (every edge);
//   - a new style resets what belongs to the style (align, flat, size,
//     thickness) to its defaults, clears a disabled flag the old style
//     (none) left behind, and moves modules sitting in groups the new
//     style does not render to its last group, so nothing is hidden.

function _copy(panel) {
    return JSON.parse(JSON.stringify(panel));
}

// Edges selectable for `style` (all edges when no style is given).
function edgesFor(style) {
    return style ? PanelStyles.get(style).edges.slice() : PanelStyles.ALL_EDGES.slice();
}

// Styles selectable on `edge`.
function stylesFor(edge) {
    return PanelStyles.ids().filter(function (id) {
        return PanelStyles.supportsEdge(id, edge);
    });
}

function _moveHiddenGroups(panel, meta) {
    var target = meta.groups.indexOf("end") !== -1 ? "end" : meta.groups[meta.groups.length - 1];
    if (!target)
        return;
    PanelStyles.GROUPS.forEach(function (g) {
        if (meta.groups.indexOf(g) !== -1 || !(panel.groups && panel.groups[g] && panel.groups[g].length))
            return;
        panel.groups[target] = (panel.groups[target] || []).concat(panel.groups[g]);
        panel.groups[g] = [];
    });
}

// A copy of `panel` with `field` (edge | style | align | enabled | ...) set
// to `value` and everything that depends on it kept consistent.
function apply(panel, field, value) {
    var p = _copy(panel);
    if (field === "style") {
        if (!PanelStyles.has(value))
            return p;
        var meta = PanelStyles.get(value);
        p.style = value;
        if (!PanelStyles.supportsEdge(value, p.edge))
            p.edge = meta.edges[0];
        p.align = meta.floating ? "center" : "fill";
        p.flat = meta.flat;
        p.size = 0;
        p.thickness = 0;
        p.enabled = !PanelStyles.isHidden(value);
        _moveHiddenGroups(p, meta);
        return p;
    }
    if (field === "edge") {
        p.edge = value;
        if (!PanelStyles.supportsEdge(p.style, value)) {
            p.style = "classic";
            p.flat = PanelStyles.get("classic").flat;
        }
        return p;
    }
    p[field] = value;
    return p;
}
