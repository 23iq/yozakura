.pragma library

var data = {
    // Off: the notch only appears while it shows a view (launcher, power
    // menu...); its activities move to the bar or corner pills
    // (modules/shell/LayoutModel.js)
    "enabled": true,
    "position": "top",
    // start | center | end along the edge (modules/shell/EdgeLayout.js)
    "align": "center",
    "hoverRegionHeight": 8,
    "keepHidden": false,
    "noMediaDisplay": "userHost",
    "customText": "Yozakura",
    "disableHoverExpansion": true,
    "hoverExpandDelay": 90,
    "hoverCollapseDelay": 200,
    "expandOn": "hover",
    "expandedMediaWidth": 440,
    "mediaAnimationDuration": 160,
    "expandedArtworkSize": 64,
    "microphoneNoticeDuration": 1800,
    "visualizer": true,
    // Media panel layout: row (compact player row) | artwork (large art,
    // tinted card; panels/MediaPanel.qml in modules/widgets/defaultview)
    "mediaStyle": "row",
    // attached | island | pill (modules/notch/styles/NotchStyles.js);
    // activities: order/side/enabled of the island's activities
    // ({id, side, enabled}, modules/widgets/defaultview/activities/ActivityRegistry.js).
    "style": "attached",
    "activities": [],
    // Where live activities show while the notch shares its edge with a
    // bar: auto (as chips in the bar, the notch never grows for them) |
    // notch (header segments) | bar (always as bar chips when there is a
    // bar). modules/shell/LayoutModel.js activityPresentation
    "activitiesIn": "auto",
    // Live activity sources (recording, downloads, timers, ...) shown in the
    // island or as bar islands (modules/services/activities).
    "liveActivities": {
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
    }
}
