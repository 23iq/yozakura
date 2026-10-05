.pragma library

// Active workspace indicator styles (workspaces.indicatorStyle).
//
// Entry fields:
//   id         config value
//   label      human readable name
//   component  QML file in this directory. It fills the indicator box (the
//              active slot, stretched over the slots it is travelling
//              between) and gets `indicator` (ActiveIndicator.qml: vertical,
//              slotSize, occupied, baseRadius, padding, workspaceId)
//   filled     true when the label sits on the indicator's fill (it then
//              takes the fill's item color), false when the label stays on
//              the bar background (it then takes the accent color)
//
// To add a style: one component file here + one entry below; validation,
// the catalog and the settings chips pick it up.

var DEFAULT_ID = "pill";

var STYLES = [
    { "id": "pill", "label": "Pill", "component": "PillIndicator.qml", "filled": true },
    { "id": "underline", "label": "Underline", "component": "UnderlineIndicator.qml", "filled": false },
    { "id": "dot", "label": "Dot", "component": "DotIndicator.qml", "filled": false },
    { "id": "brush", "label": "Brush", "component": "BrushIndicator.qml", "filled": true },
    { "id": "bracket", "label": "Bracket", "component": "BracketIndicator.qml", "filled": false }
];

function ids() {
    return STYLES.map(function (s) {
        return s.id;
    });
}

function isValid(id) {
    return ids().indexOf(id) !== -1;
}

function get(id) {
    for (var i = 0; i < STYLES.length; i++) {
        if (STYLES[i].id === id)
            return STYLES[i];
    }
    return STYLES[0];
}

function filled(id) {
    return get(id).filled;
}

// Box of the indicator inside the workspaces widget: the slots between the
// two animated indices (idx1 leads, idx2 trails: the stretchy transition).
function box(idx1, idx2, slot, padding, vertical) {
    var start = Math.min(idx1, idx2) * slot + padding;
    var span = Math.abs(idx1 - idx2) * slot + slot;
    return vertical ? { "x": padding, "y": start, "width": slot, "height": span } : { "x": start, "y": padding, "width": span, "height": slot };
}

// Thin bar along the box: under the label (horizontal) or beside it
// (vertical), shortened so a single slot keeps a centered accent.
function underline(w, h, slot, vertical) {
    var t = Math.max(2, Math.round(slot * 0.1));
    var inset = Math.round(slot * 0.22);
    var gap = Math.max(1, Math.round(slot * 0.06));
    if (vertical)
        return { "x": w - t - gap, "y": inset, "width": t, "height": Math.max(t, h - inset * 2), "radius": t / 2 };
    return { "x": inset, "y": h - t - gap, "width": Math.max(t, w - inset * 2), "height": t, "radius": t / 2 };
}

// Small dot under (horizontal) or beside (vertical) the label; a capsule
// while it travels between slots.
function dot(w, h, slot, vertical) {
    var d = Math.max(4, Math.round(slot * 0.16));
    var gap = Math.max(1, Math.round(slot * 0.06));
    var stretch = (vertical ? h : w) - slot;
    if (vertical)
        return { "x": w - d - gap, "y": (slot - d) / 2, "width": d, "height": d + stretch, "radius": d / 2 };
    return { "x": (slot - d) / 2, "y": h - d - gap, "width": d + stretch, "height": d, "radius": d / 2 };
}
