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
    "hoverToReveal": true,
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
        "clock": {
            "showWeather": true
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
        }
    }
}
