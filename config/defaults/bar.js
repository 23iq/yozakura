.pragma library

var data = {
    "position": "top",
    "launcherIcon": "",
    "launcherIconTint": true,
    "launcherIconSize": 24,
    "screenList": [],
    "enableFirefoxPlayer": false,
    "frameEnabled": false,
    "frameThickness": 6,
    "pinnedOnStartup": true,
    "hoverRegionHeight": 8,
    "showPinButton": true,
    "availableOnFullscreen": false,
    "use12hFormat": false,
    "containBar": false,
    "keepBarShadow": false,
    "keepBarBorder": false,
    "clockShowDate": false,
    "compact": false,
    "layout": {
        "style": "classic",
        "left": ["launcher", "workspaces", "layoutSelector", "pin"],
        "right": ["presets", "tools", "systray", "keyboardLayout", "controls", "battery", "clock", "power"],
        "drawer": []
    },
    // Multi-panel layouts (modules/bar/panels/PanelLayout.js). Empty = the
    // single legacy bar from position/layout/screenList.
    "panels": [],
    // Per-module options, shared by every panel showing the module
    "moduleOptions": {
        "windowTitle": {
            "show": "both",
            "showIcon": true,
            "maxWidth": 420
        },
        "taskbar": {
            "showPinned": true,
            "showLabels": false,
            "indicator": "dot"
        },
        "systemStats": {
            "items": ["cpu", "ram", "gpuTemp", "net"]
        },
        "weather": {
            "showDescription": true
        },
        "media": {
            "showTitle": true,
            "visualizer": true
        },
        "clock": {
            "showWeather": true,
            "face": "digital",
            "pomodoroStyle": "ring",
            "panelStyle": "column",
            // Initial clock grid; an empty cells list keeps the panel empty.
            "panel": {
                "cells": [
                    { "widget": "weather", "x": 0, "y": 0, "w": 2, "h": 2 },
                    { "widget": "pomodoro", "x": 0, "y": 2, "w": 1, "h": 2 },
                    { "widget": "agenda", "x": 1, "y": 2, "w": 1, "h": 2 },
                    { "widget": "worldClocks", "x": 0, "y": 4, "w": 2, "h": 1 }
                ]
            }
        },
        "worldClocks": {
            "zones": [
                {
                    "label": "Tokyo",
                    "zone": "Asia/Tokyo"
                },
                {
                    "label": "London",
                    "zone": "Europe/London"
                },
                {
                    "label": "New York",
                    "zone": "America/New_York"
                }
            ]
        },
        "workspaceTags": {
            "brackets": true
        },
        "downloads": {
            "folder": "",
            "count": 8
        },
        "workspacePreviews": {
            "count": 4
        },
        // The bar read as one line (modules/bar/sentence/Sentence.js):
        // fragments in order, the ranking that keeps them on a narrow bar,
        // separator dash | dot | comma | none, verbosity short | full,
        // typeface body | editorial (theme.type.editorial), maxWidth px
        // (0 = half the bar).
        "sentence": {
            "fragments": ["clock", "window", "workspace", "battery", "media", "notifications"],
            "priority": ["clock", "media", "window", "battery", "notifications", "workspace", "volume", "weather", "network"],
            "separator": "dash",
            "verbosity": "full",
            "typeface": "editorial",
            "maxWidth": 0
        }
    }
}
