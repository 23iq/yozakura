.pragma library

// Catalog metadata of config/defaults/apps.js (format: config/meta/Meta.js).

var description = "External app theming: one switch per app the palette is written to (modules/theme/AppThemes.js), and the kitty font written next to its colors.";

var keys = {
    "theming.*": {
        "description": "Write the shell palette to this app when colors change (modules/theme/AppThemes.js); off leaves the app's theme alone."
    },
    "kitty.font": {
        "format": "font-family",
        "description": "Kitty font family (empty = keep the font from kitty.conf)."
    },
    "kitty.fontSize": {
        "min": 4,
        "max": 72,
        "unit": "pt",
        "description": "Kitty font size, used with kitty.font."
    }
};
