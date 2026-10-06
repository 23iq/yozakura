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
.import "Advanced.js" as Advanced
.import "dock.js" as Dock
.import "overview.js" as Overview
.import "sidebar.js" as Sidebar

// Settings information architecture: the sidebar tree and its pages.
//
// The sidebar shows the 12 top-level `groups` (one per shell element:
// Layout, Bar, Island, ...); a group opens its first category and, when it
// has several, lists them under itself. A category is one of:
//   * schema-driven: has `sections` (see appearance.js) - rendered by
//     SettingsPage.qml, searchable entry by entry; entries flagged
//     `advanced: true` gather in a collapsed "Advanced" block (Advanced.js);
//   * a page: has `page` - a hand-written page mapped by name in
//     SettingsShell.pages (Connect pages host the live device controls).
// Every category is listed in exactly one group. `resolve(id)` accepts a
// category id, a moved id (MOVED) or a group id, so old deep links and the
// new tree both work.

var groups = [
    {
        "id": "layout",
        "icon": "frameCorners",
        "title": "prefs.group.layout",
        "categories": ["layout"]
    },
    {
        "id": "bar",
        "icon": "squaresFour",
        "title": "prefs.group.bar",
        "categories": ["bar"]
    },
    {
        "id": "island",
        "icon": "dotsThree",
        "title": "prefs.group.island",
        "categories": ["notch"]
    },
    {
        "id": "dock",
        "icon": "dock",
        "title": "prefs.group.dock",
        "categories": ["dock"]
    },
    {
        "id": "launcher",
        "icon": "magnifyingGlass",
        "title": "prefs.group.launcher",
        "categories": ["launcher"]
    },
    {
        "id": "dashboard",
        "icon": "robot",
        "title": "prefs.group.dashboard",
        "categories": ["dashboard", "ai", "ai-providers", "ai-code"]
    },
    {
        "id": "popups",
        "icon": "bell",
        "title": "prefs.group.popups",
        "categories": ["notifications", "osd", "menus"]
    },
    {
        "id": "lockscreen",
        "icon": "lock",
        "title": "prefs.group.lockscreen",
        "categories": ["lockscreen"]
    },
    {
        "id": "desktop",
        "icon": "monitor",
        "title": "prefs.group.desktop",
        "categories": ["desktop", "overview"]
    },
    {
        "id": "look",
        "icon": "paintBrush",
        "title": "prefs.group.look",
        "categories": ["appearance", "icons-type", "wallpapers"]
    },
    {
        "id": "presets",
        "icon": "magicWand",
        "title": "prefs.group.presets",
        "categories": ["presets"]
    },
    {
        "id": "system",
        "icon": "gear",
        "title": "prefs.group.system",
        "categories": ["system", "displays", "keyboard", "windows", "specials", "terminal", "input", "voice", "timers", "routines", "network", "bluetooth", "sound", "effects", "extras", "mods", "updates", "about"]
    }
];

// A hand-written page (SettingsShell.pages[name]).
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

// Categories that moved into another page: old deep links land there.
var MOVED = {
    "surfaces": "appearance",
    "bar-classic": "bar",
    "sidebar": "ai"
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
    page("network", "wifiHigh", "Network", "network wifi internet ethernet connection"),
    page("bluetooth", "bluetooth", "Bluetooth", "bluetooth devices pairing headphones"),
    page("sound", "speakerHigh", "Sound", "sound audio volume mixer output input microphone speaker"),
    page("effects", "waveform", "Effects", "equalizer easyeffects bass audio effects"),
    withSections(Ai.category, Sidebar.sections),
    AiProviders.category,
    AiCode.category,
    page("mods", "puzzlePiece", "Mods", "mods extensions plugins modifications install"),
    {
        "id": "presets",
        "icon": "magicWand",
        "title": "prefs.cat.presets",
        "description": "prefs.cat.presets.desc",
        "keywords": "presets studio save load profiles themes layouts looks gallery mixer mix duplicate import export share try",
        "page": "PresetStudio"
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

categories = categories.map(Advanced.apply);

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

// The group (top-level sidebar entry) a category belongs to.
function groupOf(categoryId) {
    for (var i = 0; i < groups.length; i++) {
        if (groups[i].categories.indexOf(categoryId) !== -1)
            return groups[i];
    }
    return null;
}

// A category id (old deep links) or a group id (opens its first page).
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
