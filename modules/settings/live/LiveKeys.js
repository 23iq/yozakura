.pragma library

// What the parts of a live preview stand for in the settings: the keys a
// bar module's StageSpot lights for, and the Bar card a click on a module
// opens. Generic: a module without an entry lights for its own options
// (bar.moduleOptions.<id>) and opens the bar's layout card, so a new module
// needs nothing here. Tests: tests/live-preview.test.cjs.

var MODULE_KEYS = {
    "clock": ["bar.clockShowDate", "bar.use12hFormat", "bar.moduleOptions.clock"],
    "workspaces": ["workspaces"],
    "launcher": ["bar.launcherIcon", "bar.launcherIconTint", "bar.launcherIconSize"],
    "pin": ["bar.showPinButton", "bar.pinnedOnStartup"]
};

// The Bar tab's card of a module (schema/bar.js section ids).
var MODULE_SECTIONS = {
    "clock": "clock",
    "workspaces": "workspaces"
};

function moduleKeys(id) {
    return MODULE_KEYS[id] || ["bar.moduleOptions." + id];
}

function sectionOf(id) {
    return MODULE_SECTIONS[id] || "layout";
}

// The settings a snapshot picture of a bar (LivePanel) or of the dock
// (LiveDock) draws from: a change of one of them pictures it again, any
// other key (motion, wallpaper, the AI, the island's behaviour...) leaves
// the picture alone. Colours are followed apart (Colors). The theme keys
// are the ones the kit and the bar draw with (fonts, roundness, density,
// shape, language, glass, shadows, the sr* surfaces, corners, icons, text
// style, the surface effect, the progress ink).
var THEME_DRAWN = /^theme\.(font|monoFont|roundness|density|shape|language|glass|shadow|sr|enableCorners|icons|type|surfaceEffect|progressRole)/;
var PICTURE_KEYS = {
    // (a bar holds the integrated dock, the island's edge picks the primary
    // panel, specials are modules of it)
    "bar": /^(bar|workspaces|dock|notch|specials)\./,
    // (a dock in the bar follows the bar's look)
    "dock": /^(dock|bar)\./
};

function redraws(kind, key) {
    var k = String(key);
    var own = PICTURE_KEYS[kind];
    return !!own && (own.test(k) || THEME_DRAWN.test(k));
}
