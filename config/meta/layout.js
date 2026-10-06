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
    "dashboard.tabs": {
        "description": "Dashboard tabs in order: [{id, visible}]."
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
        "description": "Placed dashboard cells; empty uses the registry's default grid."
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
