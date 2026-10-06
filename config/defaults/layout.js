.pragma library

// Where the launcher and dashboard live, the dashboard tab/grid layout, the
// side sheet and the OSD. "auto" values follow the bar/notch placement
// (modules/shell/EdgeLayout.js).
var data = {
    "launcher": {
        "host": "notch",
        "resultStyle": "list",
        "preview": true,
        "compactWhenEmpty": false
    },
    "dashboard": {
        "host": "notch",
        "tabs": [
            {
                "id": "widgets",
                "visible": true
            },
            {
                "id": "wallpapers",
                "visible": true
            },
            {
                "id": "metrics",
                "visible": true
            }
        ],
        // cells: [] = the registry's default grid.
        "grid": {
            "cols": 4,
            "cells": []
        }
    },
    "sheet": {
        "side": "auto"
    },
    // notch: in the notch; fullscreen: big buttons over a dimmed screen;
    // radial: a ring at the cursor (modules/widgets/powermenu/styles).
    "powermenu": {
        "style": "notch"
    },
    "tools": {
        "style": "notch"
    },
    // fullscreen keeps the frosted full-screen sheet; spotlight / sheet use
    // the launcher's hosts (modules/shell/hosts).
    "cheatsheet": {
        "host": "fullscreen"
    },
    "osd": {
        "position": "auto",
        "style": "pill",
        "timeout": 2500
    }
};
