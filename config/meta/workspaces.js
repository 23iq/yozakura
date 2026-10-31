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
        "description": "Shape of the active workspace indicator: pill, underline, dot, brush (sumi-e stroke), bracket ([1], retro) or branch (a blossom branch: a bud per empty workspace, a petal per window) (registry: modules/bar/workspaces/indicators/IndicatorStyles.js)."
    },
    "branchBlossom": {
        "enum": Enums.branchBlossoms(),
        "description": "Blossom shape of the branch indicator (indicatorStyle branch): sakura (notched petals), plum (round petals), round (dots) or leaf."
    },
    "branchColor": {
        "enum": Enums.COLOR_ROLES,
        "description": "Palette role of the branch indicator's blossoms and buds; the active workspace always takes the accent."
    },
    "branchPetalFall": {
        "description": "Branch indicator: a petal falls when a window closes (only with animations on)."
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
