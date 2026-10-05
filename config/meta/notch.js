.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/notch.js (format: config/meta/Meta.js).

var description = "The notch (dynamic island): style, edge, hover/click expansion, media preview and what it shows when idle.";

var keys = {
    "theme": {
        "enum": Enums.NOTCH_THEMES
    },
    "position": {
        "enum": Enums.VERTICAL_EDGES
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
    }
};
