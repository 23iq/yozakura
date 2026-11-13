.pragma library

// The dock's look card (DockLookEditor.qml): its size steps and running
// indicators. Pure (tests/settings-dock-look.test.cjs).

// dock.iconSize steps, a label each (the default, 24 px, is "Medium")
var SIZES = [
    { "px": 20, "label": "prefs.dock.size.small" },
    { "px": 24, "label": "prefs.dock.size.medium" },
    { "px": 32, "label": "prefs.dock.size.large" },
    { "px": 44, "label": "prefs.dock.size.huge" }
];

// none = no running indicators (dock.showRunningIndicators off)
var INDICATORS = [
    { "id": "none", "label": "prefs.dock.indicator.none" },
    { "id": "dot", "label": "prefs.dock.indicator.dot" },
    { "id": "line", "label": "prefs.dock.indicator.line" },
    { "id": "glow", "label": "prefs.dock.indicator.glow" },
    { "id": "brush", "label": "prefs.dock.indicator.brush" }
];

// The step nearest a size (any px value the CLI or a preset set).
function nearestSize(px) {
    var best = 0;
    for (var i = 1; i < SIZES.length; i++)
        if (Math.abs(SIZES[i].px - px) < Math.abs(SIZES[best].px - px))
            best = i;
    return best;
}

// The indicator a dock shows: "none" while running indicators are off.
function indicatorOf(showRunning, style) {
    if (showRunning === false)
        return "none";
    return style || "dot";
}

// The keys picking an indicator writes.
function indicatorWrites(id) {
    if (id === "none")
        return { "dock.showRunningIndicators": false };
    return { "dock.showRunningIndicators": true, "dock.indicator": id };
}
