.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/workspaces.js (format: config/meta/Meta.js).

var description = "Workspace indicator in the bar: count, numbers, numeral style, app icons and special workspaces.";

var keys = {
    "shown": {
        "min": 1,
        "max": 20
    },
    "numeralStyle": {
        "enum": Enums.numeralStyles(),
        "description": "Numeral system of workspace numbers (registry: modules/bar/workspaces/WorkspaceNumerals.js)."
    },
    "indicatorStyle": {
        "enum": Enums.indicatorStyles(),
        "description": "Shape of the active workspace indicator: pill, underline, dot, brush (sumi-e stroke) or bracket ([1], retro) (registry: modules/bar/workspaces/indicators/IndicatorStyles.js)."
    },
    "showSpecialWorkspace": {
        "description": "Show the special (scratchpad) workspace indicator."
    },
    "specialWorkspaceAnimationDuration": {
        "min": 0,
        "max": 2000,
        "unit": "ms",
        "description": "Animation of the special workspace indicator."
    },
    "specialWorkspaceFont": {
        "format": "font-family",
        "description": "Font of the special workspace name (empty = UI font)."
    },
    "numeralFont": {
        "format": "font-family",
        "description": "Font for workspace numerals (empty = picked automatically for the numeral style)."
    }
};
