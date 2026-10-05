.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/dock.js (format: config/meta/Meta.js).

var description = "App dock: pinned and running apps, its style (default/floating/integrated into the bar), edge, size and auto-hide.";

var keys = {
    "enabled": {
        "description": "Show the dock."
    },
    "theme": {
        "enum": Enums.DOCK_THEMES,
        "description": "Dock style; integrated puts the apps inside the bar."
    },
    "position": {
        "enum": Enums.EDGES,
        "description": "Screen edge of the dock."
    },
    "height": {
        "min": 24,
        "max": 128,
        "unit": "px",
        "description": "Dock thickness."
    },
    "iconSize": {
        "min": 12,
        "max": 96,
        "unit": "px",
        "description": "App icon size."
    },
    "spacing": {
        "min": 0,
        "max": 32,
        "unit": "px",
        "description": "Space between icons."
    },
    "margin": {
        "min": 0,
        "max": 64,
        "unit": "px",
        "description": "Distance from the screen edge."
    },
    "hoverRegionHeight": {
        "min": 0,
        "max": 64,
        "unit": "px",
        "description": "Size of the edge strip that reveals the hidden dock."
    },
    "pinnedOnStartup": {
        "description": "Dock starts pinned (always visible)."
    },
    "hoverToReveal": {
        "description": "Reveal the hidden dock when the pointer touches its edge."
    },
    "availableOnFullscreen": {
        "description": "Allow revealing the dock over fullscreen windows."
    },
    "showRunningIndicators": {
        "description": "Dots under running apps."
    },
    "showPinButton": {
        "description": "Show the pin (keep visible) button."
    },
    "showOverviewButton": {
        "description": "Show the workspace overview button."
    },
    "ignoredAppRegexes": {
        "items": {
            "type": "string",
            "format": "regex"
        },
        "description": "App ids matching these regexes never appear in the dock."
    },
    "screenList": {
        "items": {
            "type": "string"
        },
        "description": "Monitor names to show the dock on; empty = every monitor."
    },
    "keepHidden": {
        "description": "Keep the dock hidden until revealed."
    },
    "magnification": {
        "description": "Magnify dock icons under the pointer (dock-style panels)."
    },
    "magnificationScale": {
        "min": 1,
        "max": 2.5,
        "description": "Size of the icon under the pointer when magnifying."
    },
    "launchBounce": {
        "description": "Bounce a dock icon while its app launches."
    }
};
