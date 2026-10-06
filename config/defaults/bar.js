.pragma library

var data = {
    "position": "top",
    "launcherIcon": "",
    "launcherIconTint": true,
    "launcherIconFullTint": true,
    "launcherIconSize": 24,
    "pillStyle": "default",
    "screenList": [],
    "enableFirefoxPlayer": false,
    "barColor": [["surface", 0.0]],
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
    "activities": {
        "enabled": true,
        "presentation": "notch",
        "maxVisible": 4,
        "sources": {
            "recording": true,
            "privacy": true,
            "timers": true,
            "tasks": true,
            "notificationProgress": true,
            "jobView": true,
            "browserDownloads": true,
            "steam": true,
            "terminal": true,
            "fileOps": true,
            "packages": true,
            "torrents": true,
            "aria2": true,
            "syncthing": true,
            "launchers": true
        },
        "downloads": {
            "aggregate": true,
            "showSpeed": true,
            "endpoints": {
                "qbittorrent": "http://127.0.0.1:8080",
                "transmission": "http://127.0.0.1:9091/transmission/rpc",
                "deluge": "http://127.0.0.1:8112/json",
                "aria2": "http://127.0.0.1:6800/jsonrpc",
                "syncthing": ""
            },
            "secrets": {
                "qbittorrent": "",
                "transmission": "",
                "deluge": "deluge",
                "aria2": ""
            }
        }
    },
    "layout": {
        "style": "classic",
        "left": ["launcher", "workspaces", "layoutSelector", "pin"],
        "right": ["presets", "tools", "systray", "controls", "battery", "clock", "power"],
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
