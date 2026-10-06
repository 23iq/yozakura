.pragma library

// Catalog metadata of config/defaults/layout.js (see config/meta/Meta.js for
// the entry format).

var description = "Where the launcher and dashboard live (notch or a separate window), launcher result style, dashboard tabs and widget grid, side sheet placement and the OSD.";

var HOSTS = ["notch", "window"];

var keys = {
    "launcher": {
        "description": "Launcher placement and look."
    },
    "launcher.host": {
        "enum": HOSTS,
        "description": "Where the launcher opens: grown from the notch or as a centered window."
    },
    "launcher.resultStyle": {
        "enum": ["list", "grid"],
        "description": "How launcher results are laid out."
    },
    "launcher.preview": {
        "description": "Show a preview pane next to the selected launcher result."
    },
    "launcher.compactWhenEmpty": {
        "description": "Collapse the launcher to its search field until something is typed."
    },
    "dashboard": {
        "description": "Dashboard placement, tabs and widget grid."
    },
    "dashboard.host": {
        "enum": HOSTS,
        "description": "Where the dashboard opens: grown from the notch or as a window."
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
        "description": "Placed dashboard widgets: [{widget, x, y, w, h}] in grid cells. widget = player | quickControls | calendar | specials | notifications | levels | weather | metricsSummary (modules/widgets/dashboard/widgets/WidgetRegistry.js). Empty or invalid uses the default grid; overlaps are pushed down and compacted. Edited in place from the dashboard (pencil button)."
    },
    "sheet": {
        "description": "Side sheet (notifications, quick settings)."
    },
    "sheet.side": {
        "enum": ["auto", "left", "right"],
        "description": "Edge the side sheet slides from; auto follows the bar."
    },
    "osd": {
        "description": "On-screen display for volume and brightness."
    },
    "osd.position": {
        "enum": ["auto", "top", "bottom", "left", "right"],
        "description": "Screen edge of the OSD; auto is opposite the bar."
    },
    "osd.style": {
        "enum": ["pill", "bar", "minimal"],
        "description": "OSD look."
    }
};
