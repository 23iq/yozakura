.pragma library

// Default bento grid of the bar clock panel (ClockPanel.qml), in widgets of
// the shared WidgetRegistry; bar.moduleOptions.clock.panel.cells overrides it.
var COLS = 2;

function defaultGrid(cols) {
    return [
        { widget: "weather", x: 0, y: 0, w: 2, h: 2 },
        { widget: "pomodoro", x: 0, y: 2, w: 1, h: 2 },
        { widget: "agenda", x: 1, y: 2, w: 1, h: 2 },
        { widget: "worldClocks", x: 0, y: 4, w: 2, h: 1 }
    ];
}

// bar.moduleOptions is a plain `var` object: return an updated copy with
// clock.panel.cells set (the other options untouched).
function withCells(options, cells) {
    var copy = JSON.parse(JSON.stringify(options || {}));
    copy.clock = copy.clock && typeof copy.clock === "object" ? copy.clock : {};
    copy.clock.panel = copy.clock.panel && typeof copy.clock.panel === "object" ? copy.clock.panel : {};
    copy.clock.panel.cells = JSON.parse(JSON.stringify(cells || []));
    return copy;
}
