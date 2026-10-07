.pragma library

// Catalog metadata of config/defaults/layout.js (see config/meta/Meta.js for
// the entry format).

var description = "Where the launcher and dashboard live (notch, centered spotlight or side sheet), launcher result style, dashboard tabs and widget grid, side sheet placement and the OSD.";

var HOSTS = ["notch", "spotlight", "sheet"];

var keys = {
    "launcher": {
        "description": "Launcher placement and look."
    },
    "launcher.host": {
        "enum": HOSTS,
        "description": "Where the launcher opens: grown from the notch, centered over a dimmed screen (spotlight) or as a full-height side sheet. Unknown values fall back to notch."
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
        "description": "Where the dashboard opens: grown from the notch, centered over a dimmed screen (spotlight) or as a full-height side sheet. Unknown values fall back to notch."
    },
    "dashboard.home": {
        "enum": ["composed", "bento"],
        "description": "Home view of the dashboard widgets tab: composed (clock, player, toggles, levels, calendar and notifications in a fixed two-column layout) or bento (the editable widget grid)."
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
        "enum": ["notch", "fullscreen", "radial"],
        "description": "Power menu look: a row in the notch, large buttons over a dimmed screen, or a ring at the cursor. Shutdown, reboot and logout are held to confirm."
    },
    "tools": {
        "description": "Tools menu look."
    },
    "tools.style": {
        "enum": ["notch", "radial"],
        "description": "Tools menu look: a row in the notch or a ring at the cursor."
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
        "enum": ["pill", "edge", "island", "bar-inline"],
        "description": "OSD look: pill, a slim bar on the screen edge, inside the notch island, or inline in the bar."
    },
    "osd.timeout": {
        "min": 800,
        "max": 8000,
        "description": "How long the OSD stays visible, in milliseconds."
    }
};
