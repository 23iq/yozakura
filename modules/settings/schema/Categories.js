.pragma library
.import "appearance.js" as Appearance
.import "icons-type.js" as IconsType
.import "wallpapers.js" as Wallpapers
.import "bar.js" as Bar
.import "notch.js" as Notch
.import "ai.js" as Ai
.import "aiproviders.js" as AiProviders
.import "aicode.js" as AiCode
.import "input.js" as Input
.import "lockscreen.js" as Lockscreen
.import "launcher.js" as Launcher
.import "desktop.js" as Desktop
.import "dock.js" as Dock
.import "windows.js" as Windows
.import "system.js" as System
.import "voice.js" as Voice
.import "updates.js" as Updates
.import "terminal.js" as Terminal
.import "notifications.js" as Notifications
.import "specials.js" as Specials
.import "timers.js" as Timers
.import "routines.js" as Routines
.import "layout.js" as Layout
.import "dashboard.js" as Dashboard
.import "osd.js" as Osd
.import "menus.js" as Menus
.import "overview.js" as Overview
.import "sidebar.js" as Sidebar
.import "presets.js" as Presets
.import "power.js" as Power

// Settings information architecture: the window's destinations and their
// tabs (modules/settings/AGENTS.md, NAVIGATION).
//
// The sidebar is one flat list of `groups` (destinations: Bar, Island, ...,
// each with an icon) in labelled blocks (SIDEBAR_SECTIONS). A destination
// holds one or more categories, shown as tabs at its top (`categories`,
// first = default tab). A category is one of:
//   * schema-driven: has `sections` (see bar.js) - rendered by
//     SettingsPage.qml, searchable entry by entry; entries flagged
//     `advanced: true` are not in the window (SchemaUtil.inWindow);
//     `stage` (Registry.STAGES name) is the live miniature at its top;
//   * a page: has `page` - a hand-written page loaded by URL
//     (Registry.PAGES).
// Every category is listed in exactly one destination. `resolve(id)`
// accepts a category id, a moved id (MOVED) or a destination id, so old
// deep links (`<app> run settings <id>`, GlobalStates.settingsCategory)
// and the new tree both work.

var groups = [
    { "id": "bar", "icon": "squaresFour", "title": "prefs.dest.bar", "categories": ["bar", "layout"] },
    { "id": "island", "icon": "dotsThree", "title": "prefs.dest.island", "categories": ["notch"] },
    { "id": "dock", "icon": "dock", "title": "prefs.dest.dock", "categories": ["dock"] },
    { "id": "launcher", "icon": "magnifyingGlass", "title": "prefs.dest.launcher", "categories": ["launcher"] },
    { "id": "dashboard", "icon": "widgets", "title": "prefs.dest.dashboard", "categories": ["dashboard"] },
    { "id": "notifications", "icon": "bell", "title": "prefs.dest.notifications", "categories": ["notifications", "osd", "menus"] },
    { "id": "lockscreen", "icon": "lock", "title": "prefs.dest.lockscreen", "categories": ["lockscreen"] },
    { "id": "desktop", "icon": "monitor", "title": "prefs.dest.desktop", "categories": ["desktop", "overview"] },
    { "id": "look", "icon": "paintBrush", "title": "prefs.dest.look", "categories": ["appearance", "icons-type"] },
    { "id": "wallpaper", "icon": "image", "title": "prefs.dest.wallpaper", "categories": ["wallpapers"] },
    { "id": "presets", "icon": "magicWand", "title": "prefs.dest.presets", "categories": ["presets", "changes"] },
    { "id": "assistant", "icon": "sparkle", "title": "prefs.dest.assistant", "categories": ["ai", "ai-providers", "ai-code"] },
    { "id": "displays", "icon": "frameCorners", "title": "prefs.dest.displays", "categories": ["displays"] },
    { "id": "input", "icon": "keyboard", "title": "prefs.dest.input", "categories": ["keyboard", "input"] },
    { "id": "windows", "icon": "appWindow", "title": "prefs.dest.windows", "categories": ["windows", "specials"] },
    { "id": "network", "icon": "wifiHigh", "title": "prefs.dest.network", "categories": ["network", "bluetooth"] },
    { "id": "sound", "icon": "speakerHigh", "title": "prefs.dest.sound", "categories": ["sound", "effects"] },
    { "id": "power", "icon": "batteryHigh", "title": "prefs.dest.power", "categories": ["power"] },
    { "id": "apps", "icon": "packageBox", "title": "prefs.dest.apps", "categories": ["terminal", "extras", "mods"] },
    { "id": "system", "icon": "gear", "title": "prefs.dest.system", "categories": ["system", "updates", "voice", "timers", "routines", "about"] }
];

// A hand-written page (Registry.PAGES[name]).
function page(id, icon, name, keywords) {
    return {
        "id": id,
        "icon": icon,
        "title": "prefs.cat." + id,
        "description": "prefs.cat." + id + ".desc",
        "keywords": keywords,
        "page": name
    };
}

// Categories (and former sidebar groups) that moved: old deep links land
// there.
var MOVED = {
    "surfaces": "appearance",
    "bar-classic": "bar",
    "sidebar": "ai",
    "popups": "notifications"
};

// A copy of `cat` with `extra` sections appended.
function withSections(cat, extra) {
    var out = {};
    for (var k in cat)
        out[k] = cat[k];
    out.sections = cat.sections.concat(extra);
    return out;
}

var categories = [
    Layout.category,
    Appearance.category,
    IconsType.category,
    Wallpapers.category,
    Bar.category,
    Notch.category,
    Dock.category,
    Overview.category,
    Launcher.category,
    Desktop.category,
    Lockscreen.category,
    Notifications.category,
    Osd.category,
    Menus.category,
    Dashboard.category,
    Specials.category,
    Windows.category,
    Terminal.category,
    Input.category,
    System.category,
    Voice.category,
    Timers.category,
    Routines.category,
    Updates.category,
    Power.category,
    page("network", "wifiHigh", "Network", "network wifi internet ethernet connection"),
    page("bluetooth", "bluetooth", "Bluetooth", "bluetooth devices pairing headphones"),
    page("sound", "speakerHigh", "Sound", "sound audio volume mixer output input microphone speaker"),
    page("effects", "waveform", "Effects", "equalizer easyeffects bass audio effects"),
    withSections(Ai.category, Sidebar.sections),
    AiProviders.category,
    AiCode.category,
    page("mods", "puzzlePiece", "Mods", "mods extensions plugins modifications install"),
    page("changes", "listChecks", "Changes", "changes changed modified differences diff what did i change reset defaults preset custom"),
    {
        "id": "presets",
        "icon": "magicWand",
        "title": "prefs.cat.presets",
        "description": "prefs.cat.presets.desc",
        "keywords": "presets studio save load profiles themes layouts looks gallery mixer mix duplicate import export share try",
        "page": "PresetStudio",
        "sections": Presets.sections
    },
    {
        "id": "displays",
        "icon": "monitor",
        "title": "prefs.cat.displays",
        "description": "prefs.cat.displays.desc",
        "keywords": "displays monitors screens resolution refresh rate hz scale dpi rotation rotate arrange layout position vrr adaptive sync identify hdmi displayport",
        "page": "Displays"
    },
    {
        "id": "keyboard",
        "icon": "keyboard",
        "title": "prefs.cat.keyboard",
        "description": "prefs.cat.keyboard.desc",
        "keywords": "keyboard layout layouts language russian english variant switch alt shift caps lock escape ctrl compose xkb options key repeat rate delay indicator type typing",
        "page": "Keyboard"
    },
    {
        "id": "extras",
        "icon": "packageBox",
        "title": "prefs.cat.extras",
        "description": "prefs.cat.extras.desc",
        "keywords": "apps extras install software packages catalog browsers chat games steam discord spotify media ai agents claude codex ollama cuda voice flatpak aur terminal fish starship",
        "page": "Extras"
    },
    {
        "id": "about",
        "icon": "info",
        "title": "prefs.cat.about",
        "description": "prefs.cat.about.desc",
        "keywords": "about version credits license notice yozakura",
        "page": "AboutPage"
    }
];

function byId(id) {
    for (var i = 0; i < categories.length; i++) {
        if (categories[i].id === id)
            return categories[i];
    }
    return null;
}

function groupById(id) {
    for (var i = 0; i < groups.length; i++) {
        if (groups[i].id === id)
            return groups[i];
    }
    return null;
}

// The destination (sidebar entry) a category belongs to.
function groupOf(categoryId) {
    for (var i = 0; i < groups.length; i++) {
        if (groups[i].categories.indexOf(categoryId) !== -1)
            return groups[i];
    }
    return null;
}

// A category id (old deep links), a moved id or a destination id (opens
// its first tab).
function resolve(id) {
    var cat = byId(MOVED[id] || id);
    if (cat)
        return cat;
    var g = groupById(id);
    return g ? byId(g.categories[0]) : null;
}

// Sidebar model: [{id, icon, title, categories: [category...]}] in order.
function sidebar() {
    return groups.map(function (g) {
        return {
            "id": g.id,
            "icon": g.icon,
            "title": g.title,
            "categories": g.categories.map(byId).filter(function (c) {
                return c !== null;
            })
        };
    });
}

// The tabs of the destination holding `categoryId`: [category...] (one tab
// = no tab strip).
function tabsOf(categoryId) {
    var g = groupOf(categoryId);
    return g ? g.categories.map(byId).filter(function (c) {
        return c !== null;
    }) : [];
}

// The sidebar's labelled blocks (SectionLabels): the shell's parts, its
// style, the assistant, then the computer itself. Every destination sits in
// exactly one block, in `groups` order (tests/settings-tree.test.cjs).
var SIDEBAR_SECTIONS = [
    {
        "id": "shell",
        "title": "prefs.sidebar.shell",
        "groups": ["bar", "island", "dock", "launcher", "dashboard", "notifications", "lockscreen", "desktop"]
    },
    {
        "id": "style",
        "title": "prefs.sidebar.style",
        "groups": ["look", "wallpaper", "presets"]
    },
    {
        "id": "assistant",
        "title": "prefs.sidebar.assistant",
        "groups": ["assistant"]
    },
    {
        "id": "computer",
        "title": "prefs.sidebar.computer",
        "groups": ["displays", "input", "windows", "network", "sound", "power", "apps", "system"]
    }
];

function sidebarSections() {
    var tree = sidebar();
    return SIDEBAR_SECTIONS.map(function (sec) {
        return {
            "id": sec.id,
            "title": sec.title,
            "groups": tree.filter(function (g) {
                return sec.groups.indexOf(g.id) >= 0;
            })
        };
    });
}

// Categories in sidebar order (keyboard navigation).
function ordered() {
    var out = [];
    groups.forEach(function (g) {
        g.categories.forEach(function (id) {
            var c = byId(id);
            if (c)
                out.push(c);
        });
    });
    return out;
}
