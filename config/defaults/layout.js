.pragma library

// Where the launcher and dashboard live, the dashboard tab/grid layout, the
// side sheet and the OSD. "auto" values follow the bar/notch placement
// (modules/shell/EdgeLayout.js); an "auto" host is the notch while it is on,
// else the surface's fallback (modules/shell/hosts/SurfaceRegistry.js).
var data = {
    "launcher": {
        "host": "auto",
        "resultStyle": "list",
        "preview": false,
        // Leading icons on list/card result rows (false: a command-line list).
        "icons": true,
        "compactWhenEmpty": false
    },
    "dashboard": {
        "host": "auto",
        // Home view of the widgets tab: stage (hero player, agenda, week,
        // notifications; modules/widgets/dashboard/stage), composed (fixed
        // two-column layout, modules/widgets/dashboard/home) or bento (the
        // editable widget grid).
        "home": "stage",
        // Stage home: the metrics strip at the bottom, the hero tinted by the art.
        "showMetrics": true,
        "heroTint": true,
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
        // Initial grid; an empty cells list is an intentionally empty dashboard.
        "grid": {
            "cols": 4,
            "cells": [
                { "widget": "player", "x": 0, "y": 0, "w": 1, "h": 3 },
                { "widget": "quickControls", "x": 1, "y": 0, "w": 2, "h": 1 },
                { "widget": "calendar", "x": 1, "y": 1, "w": 1, "h": 2 },
                { "widget": "notifications", "x": 2, "y": 1, "w": 1, "h": 2 },
                { "widget": "levels", "x": 3, "y": 0, "w": 1, "h": 3 }
            ]
        }
    },
    "sheet": {
        "side": "auto"
    },
    // Dim (and let the compositor blur) the screen behind the spotlight and
    // sheet hosts. Off: no scrim, a click outside still closes.
    "backdrop": false,
    // auto: the notch while it is on, else fullscreen (power menu) / radial
    // (tools); notch: in the notch; fullscreen: big buttons over a dimmed
    // screen; radial: a ring at the cursor (modules/widgets/powermenu/styles).
    "powermenu": {
        "style": "auto"
    },
    "tools": {
        "style": "auto"
    },
    // AI quick ask and the notch's own panels (voice, timer hub, alarm):
    // auto = the notch while it is on, else a floating card.
    "aiquick": {
        "host": "auto"
    },
    "panels": {
        "host": "auto"
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
