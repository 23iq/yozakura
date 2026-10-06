.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/notch.js (format: config/meta/Meta.js).

var description = "The notch (dynamic island): style, edge, hover/click expansion, media preview and what it shows when idle.";

var keys = {
    "enabled": {
        "description": "Show the notch at rest. Off, its live activities move to the bar (or to corner pills without a bar) and it only appears while it shows a view."
    },
    "position": {
        "enum": Enums.EDGES
    },
    "align": {
        "enum": Enums.ALIGNS,
        "description": "Where the notch sits along its edge: start, center or end."
    },
    "hoverRegionHeight": {
        "min": 0,
        "max": 40,
        "unit": "px"
    },
    "noMediaDisplay": {
        "enum": Enums.NO_MEDIA_DISPLAY
    },
    "expandOn": {
        "enum": Enums.EXPAND_ON
    },
    "hoverExpandDelay": {
        "min": 0,
        "max": 2000,
        "unit": "ms",
        "description": "Hover time before the notch expands."
    },
    "hoverCollapseDelay": {
        "min": 0,
        "max": 2000,
        "unit": "ms",
        "description": "Delay before the expanded notch collapses after the pointer leaves."
    },
    "expandedMediaWidth": {
        "min": 200,
        "max": 1200,
        "unit": "px",
        "description": "Width of the expanded media card."
    },
    "mediaAnimationDuration": {
        "min": 0,
        "max": 2000,
        "unit": "ms",
        "description": "Media card expand/collapse animation duration."
    },
    "expandedArtworkSize": {
        "min": 16,
        "max": 256,
        "unit": "px",
        "description": "Album art size in the expanded media card."
    },
    "microphoneNoticeDuration": {
        "min": 0,
        "max": 10000,
        "unit": "ms",
        "description": "How long the microphone mute/unmute notice stays."
    },
    "style": {
        "enum": Enums.NOTCH_STYLES,
        "description": "Notch look: attached to the screen edge, a floating island, or a pill that collapses to a dot when idle."
    },
    "activities": {
        "items": {
            "type": "object",
            "properties": {
                "id": {
                    "enum": ["media", "privacy", "osd", "battery", "bluetooth", "timers", "tasks", "extras"]
                },
                "side": {
                    "enum": ["leading", "trailing", "center"]
                },
                "enabled": {
                    "type": "boolean"
                }
            },
            "required": ["id"]
        },
        "description": "Order, side and on/off of the island's activities ({id, side, enabled}); missing ids use the registry defaults."
    },
    "liveActivities": {
        "description": "Live activities (recording, downloads, timers, privacy, ...)."
    },
    "liveActivities.enabled": {
        "description": "Show live activities at all."
    },
    "liveActivities.presentation": {
        "enum": Enums.ACTIVITY_PRESENTATIONS,
        "description": "Where activities appear: inside the notch, as bar islands, or nowhere."
    },
    "liveActivities.maxVisible": {
        "min": 1,
        "max": 8,
        "description": "Most activities shown at once."
    },
    "liveActivities.sources.*": {
        "description": "Track this activity source."
    },
    "liveActivities.downloads.aggregate": {
        "description": "Merge concurrent downloads into one activity."
    },
    "liveActivities.downloads.showSpeed": {
        "description": "Show transfer speed on download activities."
    },
    "liveActivities.downloads.endpoints": {
        "local": true,
        "description": "RPC/web endpoints of the download clients (machine specific, never in presets)."
    },
    "liveActivities.downloads.endpoints.*": {
        "format": "uri",
        "description": "RPC/web endpoint of this download client (empty = disabled)."
    },
    "liveActivities.downloads.secrets": {
        "local": true,
        "description": "Passwords/tokens of the download clients' RPC (never in presets)."
    },
    "liveActivities.downloads.secrets.*": {
        "secret": true,
        "description": "Password/token of this download client's RPC."
    }
};
