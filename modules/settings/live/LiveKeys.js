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
