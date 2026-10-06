.pragma library

// Bento widgets, host-agnostic: the dashboard, the desktop and the clock
// popup place them on a BentoGrid. `url` is relative to this directory
// (BentoTile resolves it). A widget fills its tile and may declare
// `cellW`, `cellH` (pixel size of one grid cell) and `compact` (true when
// the tile is a single row or column); it never reads dashboard state for
// its layout. Sizes are in grid cells.
var widgets = [
    { id: "player", url: "FullPlayer.qml", labelKey: "bento.widget.player", icon: "musicNotes",
      minW: 1, minH: 2, maxW: 2, maxH: 4, defaultW: 1, defaultH: 3 },
    { id: "quickControls", url: "QuickControls.qml", labelKey: "bento.widget.quickControls", icon: "faders",
      minW: 2, minH: 1, maxW: 3, maxH: 2, defaultW: 2, defaultH: 1 },
    { id: "calendar", url: "CalendarWidget.qml", labelKey: "bento.widget.calendar", icon: "calendar",
      minW: 1, minH: 1, maxW: 2, maxH: 3, defaultW: 1, defaultH: 2 },
    { id: "specials", url: "SpecialsPanel.qml", labelKey: "bento.widget.specials", icon: "stack",
      minW: 1, minH: 1, maxW: 4, maxH: 3, defaultW: 2, defaultH: 1 },
    { id: "notifications", url: "NotificationHistory.qml", labelKey: "bento.widget.notifications", icon: "bell",
      minW: 1, minH: 2, maxW: 4, maxH: 4, defaultW: 1, defaultH: 2 },
    { id: "levels", url: "LevelsColumn.qml", labelKey: "bento.widget.levels", icon: "sun",
      minW: 1, minH: 2, maxW: 1, maxH: 4, defaultW: 1, defaultH: 3 },
    { id: "weather", url: "WeatherWidget.qml", labelKey: "bento.widget.weather", icon: "thermometer",
      minW: 2, minH: 1, maxW: 4, maxH: 3, defaultW: 2, defaultH: 2 },
    { id: "metricsSummary", url: "MetricsSummary.qml", labelKey: "bento.widget.metricsSummary", icon: "cpu",
      minW: 1, minH: 1, maxW: 4, maxH: 2, defaultW: 2, defaultH: 1 }
];

function ids() {
    return widgets.map(function (w) { return w.id; });
}

function byId(id) {
    for (var i = 0; i < widgets.length; i++)
        if (widgets[i].id === id)
            return widgets[i];
    return null;
}

// The pre-bento widgets tab: player | quick controls over calendar and
// specials | notification history | brightness, volume and mic levels.
// Narrower grids are clamped and stacked by BentoGrid.normalize.
function defaultGrid(cols) {
    return [
        { widget: "player", x: 0, y: 0, w: 1, h: 3 },
        { widget: "quickControls", x: 1, y: 0, w: 2, h: 1 },
        { widget: "calendar", x: 1, y: 1, w: 1, h: 2 },
        { widget: "notifications", x: 2, y: 1, w: 1, h: 2 },
        { widget: "specials", x: 1, y: 3, w: 2, h: 1 },
        { widget: "levels", x: 3, y: 0, w: 1, h: 3 }
    ];
}
