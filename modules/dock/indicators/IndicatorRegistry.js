.pragma library

// Running-app indicator styles of the dock (`dock.indicator`). Each `url`
// is a component in this directory implementing the contract of
// IndicatorBase.qml: `side`, `count`, `active`, `size`.
var styles = [
    { id: "dot", url: "DotIndicator.qml", labelKey: "prefs.dock.indicator.dot" },
    { id: "line", url: "LineIndicator.qml", labelKey: "prefs.dock.indicator.line" },
    { id: "glow", url: "GlowIndicator.qml", labelKey: "prefs.dock.indicator.glow" },
    { id: "brush", url: "BrushIndicator.qml", labelKey: "prefs.dock.indicator.brush" }
];

function ids() {
    return styles.map(function (s) { return s.id; });
}

// Unknown or missing ids fall back to the dot.
function get(id) {
    for (var i = 0; i < styles.length; i++)
        if (styles[i].id === id)
            return styles[i];
    return styles[0];
}

// Orientation and the item side an indicator hugs: the screen edge the dock
// is attached to (top docks put it on top, left/right docks stack it
// vertically on their outer side).
function placement(edge) {
    if (edge === "left" || edge === "right")
        return { vertical: true, side: edge };
    return { vertical: false, side: edge === "top" ? "top" : "bottom" };
}

// How many marks to draw for `windows` open windows: at most three, short
// ones past three.
function shown(windows) {
    return { n: Math.min(windows, 3), wide: windows <= 3 };
}
