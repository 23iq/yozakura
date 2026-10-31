.pragma library

// Catalog metadata of config/defaults/layout.js (see config/meta/Meta.js for
// the entry format).

var description = "Where the launcher and dashboard live (auto, notch, centered spotlight or side sheet), launcher result style, dashboard tabs and widget grid, side sheet placement and the OSD.";

var HOSTS = ["auto", "notch", "spotlight", "sheet"];

var keys = {
    "launcher": {
        "description": "Launcher placement and look."
    },
    "launcher.host": {
        "enum": HOSTS,
        "description": "Where the launcher opens: auto (the notch while it is enabled, else spotlight), grown from the notch, centered over a dimmed screen (spotlight) or as a full-height side sheet. Unknown values behave like auto; notch while the notch is disabled shows as auto would."
    },
    "launcher.resultStyle": {
        "enum": ["list", "cards", "grid"],
        "description": "How launcher results are laid out: rows, taller cards or an app icon grid (non-app results use the list)."
    },
    "launcher.preview": {
        "description": "Show a preview pane next to the selected launcher result."
    },
    "launcher.icons": {
        "description": "Show the leading icon on launcher result rows; off gives a text-only, command-line list (the grid style always shows icons)."
    },
    "launcher.compactWhenEmpty": {
        "description": "Collapse the launcher to its search field until something is typed."
    },
    "dashboard": {
        "description": "Dashboard placement, tabs and widget grid."
    },
    "dashboard.host": {
        "enum": HOSTS,
        "description": "Where the dashboard opens: auto (the notch while it is enabled, else the side sheet), grown from the notch, centered over a dimmed screen (spotlight) or as a full-height side sheet. Unknown values behave like auto; notch while the notch is disabled shows as auto would."
    },
    "dashboard.home": {
        "enum": ["stage", "composed", "bento"],
        "description": "Home view of the dashboard widgets tab: stage (a hero player tinted by the art, the next events, the week, notifications, toggles and levels, a metrics strip), composed (clock, player, toggles, levels, calendar and notifications in a fixed two-column layout) or bento (the editable widget grid)."
    },
    "dashboard.showMetrics": {
        "description": "Stage home: show the CPU / RAM / GPU / network strip at the bottom (click opens the metrics tab)."
    },
    "dashboard.heroTint": {
        "description": "Stage home: tint the player hero with the colour of the album art (held back so the text stays readable)."
    },
    "dashboard.tabs": {
        "description": "Dashboard tabs in rail order: [{id, visible}], id = widgets | wallpapers | metrics (modules/widgets/dashboard/DashboardTabs.js). Unknown ids are ignored, missing ones are appended; at least one tab stays visible."
    },
    "dashboard.grid": {
        "description": "Widget grid of the dashboard."
    },
    "dashboard.grid.cols": {
        "min": 1,
        "max": 12,
        "description": "Columns of the dashboard widget grid."
    },
    "dashboard.grid.cells": {
        "description": "Placed dashboard widgets: [{widget, x, y, w, h}] in grid cells. widget = player | quickControls | calendar | specials | notifications | levels | weather | metricsSummary (modules/widgets/dashboard/widgets/WidgetRegistry.js). An empty list keeps the dashboard empty; an uninitialized value uses the default grid. Overlaps are pushed down and compacted. Edited in place from the dashboard (pencil button)."
    },
    "sheet": {
        "description": "Side sheet (notifications, quick settings)."
    },
    "sheet.side": {
        "enum": ["auto", "left", "right"],
        "description": "Edge the side sheet slides from; auto follows the bar."
    },
    "powermenu": {
        "description": "Power menu look."
    },
    "powermenu.style": {
        "enum": ["auto", "notch", "fullscreen", "radial"],
        "description": "Power menu look: auto (the notch while it is enabled, else fullscreen), a row in the notch, large buttons over a dimmed screen, or a ring at the cursor. Shutdown, reboot and logout are held to confirm."
    },
    "tools": {
        "description": "Tools menu look."
    },
    "tools.style": {
        "enum": ["auto", "notch", "radial"],
        "description": "Tools menu look: auto (the notch while it is enabled, else radial), a row in the notch or a ring at the cursor."
    },
    "aiquick": {
        "description": "AI quick ask placement."
    },
    "aiquick.host": {
        "enum": ["auto", "notch", "card"],
        "description": "Where the AI quick ask opens: auto (the notch while it is enabled, else a floating card), in the notch, or a floating card (not built yet: shown as spotlight)."
    },
    "panels": {
        "description": "Placement of the notch's own panels (voice, timer hub, alarm)."
    },
    "panels.host": {
        "enum": ["auto", "notch", "card"],
        "description": "Where the voice, timer hub and alarm panels open: auto (the notch while it is enabled, else a floating card), in the notch, or a floating card (not built yet: shown as spotlight)."
    },
    "cheatsheet": {
        "description": "Keybind cheatsheet placement."
    },
    "cheatsheet.host": {
        "enum": ["fullscreen", "spotlight", "sheet"],
        "description": "Where the keybind cheatsheet opens: full screen, centered over a dimmed screen (spotlight) or as a side sheet. Unknown values fall back to fullscreen."
    },
    "osd": {
        "description": "On-screen display for volume and brightness."
    },
    "osd.position": {
        "enum": ["auto", "top", "bottom", "left", "right"],
        "description": "Screen edge of the OSD; auto is opposite the bar."
    },
    "osd.style": {
        "enum": ["pill", "edge", "island", "bar-inline", "gauge"],
        "description": "OSD look: pill, a slim bar on the screen edge, inside the notch island, inline in the bar, or a gauge (a needle dial instrument)."
    },
    "osd.timeout": {
        "min": 800,
        "max": 8000,
        "description": "How long the OSD stays visible, in milliseconds."
    }
};
