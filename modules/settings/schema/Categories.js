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
.import "dashboard.js" as Dashboard
.import "osd.js" as Osd
.import "layout.js" as Layout
.import "menus.js" as Menus
.import "overview.js" as Overview
.import "sidebar.js" as Sidebar
.import "presets.js" as Presets
.import "power.js" as Power
.import "network.js" as Network
.import "bluetooth.js" as Bluetooth
.import "sound.js" as Sound
.import "effects.js" as Effects

// Settings information architecture: the window's destinations and their
// tabs (modules/settings/AGENTS.md, NAVIGATION).
//
// The window opens on a home screen (SettingsHome): a 3x3 grid of equal
// tiles, one per destination (HOME). A destination (`groups`) holds one or
// more categories, shown as tabs at the top of its page (`categories`,
// first = default tab). A category is one of:
//   * schema-driven: has `sections` (see bar.js) - rendered by
//     SettingsPage.qml as a hero (its `stage`, Registry.STAGES) over a
//     bento of cards (one per section); entries flagged `advanced: true`
//     are not in the window (SchemaUtil.inWindow);
//   * a page: has `page` - a hand-written page loaded by URL
//     (Registry.PAGES).
// Every category is listed in exactly one destination. `resolve(id)`
// accepts a category id, a moved id (MOVED) or a destination id, so old
// deep links (`<app> run settings <id>`, GlobalStates.settingsCategory)
// keep working.

var groups = [
    { "id": "look", "icon": "paintBrush", "title": "prefs.dest.look", "categories": ["appearance", "wallpapers", "icons-type", "presets", "changes"] },
    { "id": "screen", "icon": "frameCorners", "title": "prefs.dest.screen", "categories": ["bar", "notch", "dock", "desktop", "lockscreen"] },
    { "id": "windows", "icon": "appWindow", "title": "prefs.dest.windows", "categories": ["windows", "overview", "specials"] },
    { "id": "panels", "icon": "magnifyingGlass", "title": "prefs.dest.panels", "categories": ["launcher", "dashboard", "menus"] },
    { "id": "notifications", "icon": "bell", "title": "prefs.dest.notifications_focus", "categories": ["notifications", "timers"] },
    { "id": "assistant", "icon": "sparkle", "title": "prefs.dest.assistant", "categories": ["ai", "ai-providers", "ai-code", "voice"] },
    { "id": "keys", "icon": "keyboard", "title": "prefs.dest.keyboard", "categories": ["keyboard", "input"] },
    { "id": "devices", "icon": "monitor", "title": "prefs.dest.devices", "categories": ["displays", "network", "bluetooth", "sound", "effects", "power"] },
    { "id": "system", "icon": "gear", "title": "prefs.dest.system", "categories": ["system", "updates", "terminal", "extras", "mods", "routines", "about"] }
];

// The home grid: one equal tile per destination, three by three, in
// reading order (HomeLayout.js). Tile size means nothing; every tile is a
// scene of what it opens, its name and one live status line.
var HOME = groups.map(function (g) {
    return {
        "id": g.id
    };
});

// A hand-written page (Registry.PAGES[name]); `fitted`: composed like a
// converted page on a FittedFrame (tests/settings-fit.test.py checks it).
function page(id, icon, name, keywords, fitted) {
    return {
        "id": id,
        "icon": icon,
        "title": "prefs.cat." + id,
        "description": "prefs.cat." + id + ".desc",
        "keywords": keywords,
        "page": name,
        "fitted": fitted === true
    };
}

// Categories (and former sidebar groups) that moved: old deep links land
// there.
var MOVED = {
    "surfaces": "appearance",
    "bar-classic": "bar",
    "sidebar": "ai",
    "popups": "notifications",
    "island": "notch",
    // the former destinations and tabs of the 18-tile home
    "layout": "bar",
    "osd": "menus",
    "wallpaper": "wallpapers",
    "apps": "terminal",
    "fonts": "icons-type"
};

// A copy of `cat` with `entries` put into its section `sectionId` ("" = the
// first section): after the entry with key `after`, else at the start.
function withEntries(cat, sectionId, entries, after) {
    var out = {};
    for (var k in cat)
        out[k] = cat[k];
    out.sections = cat.sections.map(function (sec, i) {
        if (sectionId ? sec.id !== sectionId : i !== 0)
            return sec;
        var copy = {};
        for (var k2 in sec)
            copy[k2] = sec[k2];
        var at = after ? sec.entries.findIndex(function (e) {
            return e.key === after;
        }) + 1 : 0;
        copy.entries = sec.entries.slice(0, at).concat(entries, sec.entries.slice(at));
        return copy;
    });
    return out;
}

// A copy of `cat` whose sections `fromIds` are folded into the section
// `intoId` (their entries appended in order; a section's compositor gate
// goes onto its entries): a card of one plain row joins the card it belongs
// with, instead of a heading that repeats its only row.
function mergeInto(cat, intoId, fromIds) {
    var out = {};
    for (var k in cat)
        out[k] = cat[k];
    var moved = [];
    fromIds.forEach(function (id) {
        var sec = cat.sections.filter(function (x) {
            return x.id === id;
        })[0];
        if (!sec)
            throw new Error("mergeInto: no section " + id + " in " + cat.id);
        sec.entries.forEach(function (e) {
            if (sec.compositor && !e.compositor) {
                var c = {};
                for (var f in e)
                    c[f] = e[f];
                c.compositor = sec.compositor;
                moved.push(c);
            } else {
                moved.push(e);
            }
        });
    });
    var found = false;
    out.sections = cat.sections.filter(function (x) {
        return fromIds.indexOf(x.id) < 0;
    }).map(function (x) {
        if (x.id !== intoId)
            return x;
        found = true;
        var c = {};
        for (var f in x)
            c[f] = x[f];
        c.entries = x.entries.concat(moved);
        return c;
    });
    if (!found)
        throw new Error("mergeInto: no section " + intoId + " in " + cat.id);
    if (cat.row)
        out.row = cat.row.filter(function (r) {
            return fromIds.indexOf(typeof r === "string" ? r : r.id) < 0;
        });
    return out;
}

// A copy of `cat` with the entry `key` moved to the head of the section
// `toId` (a feature's switch at the top of its own card).
function moveEntry(cat, key, toId) {
    var entry = null;
    var secs = cat.sections.map(function (x) {
        var found = x.entries.filter(function (e) {
            return e.key === key;
        })[0];
        if (!found)
            return x;
        entry = found;
        var c = {};
        for (var f in x)
            c[f] = x[f];
        c.entries = x.entries.filter(function (e) {
            return e !== found;
        });
        return c;
    });
    if (!entry)
        throw new Error("moveEntry: no entry " + key + " in " + cat.id);
    var out = {};
    for (var k in cat)
        out[k] = cat[k];
    out.sections = secs.map(function (x) {
        if (x.id !== toId)
            return x;
        var c = {};
        for (var f in x)
            c[f] = x[f];
        c.entries = [entry].concat(x.entries);
        return c;
    });
    return out;
}

// A copy of `cat` without its sections `ids`.
function withoutSections(cat, ids) {
    var out = {};
    for (var k in cat)
        out[k] = cat[k];
    out.sections = cat.sections.filter(function (sec) {
        return ids.indexOf(sec.id) < 0;
    });
    return out;
}

// The sections `ids` of `cat`.
function sectionsOf(cat, ids) {
    return cat.sections.filter(function (sec) {
        return ids.indexOf(sec.id) >= 0;
    });
}

// A copy of `cat` with `extra` sections appended.
function withSections(cat, extra) {
    var out = {};
    for (var k in cat)
        out[k] = cat[k];
    out.sections = cat.sections.concat(extra);
    return out;
}

var categories = [
    // the theme: light or dark beside the visual style, one line of pictures
    mergeInto(mergeInto(Appearance.category, "palette", ["accents"]), "mode", ["language"]),
    IconsType.category,
    mergeInto(Wallpapers.category, "panorama", ["transition"]),
    mergeInto(withSections(Bar.category, [Layout.builderSection]), "autohide", ["screens"]),
    mergeInto(Notch.category, "notch", ["behaviour", "place", "idle"]),
    Dock.category,
    mergeInto(Overview.category, "grid", ["size", "wallpaper"]),
    withEntries(Launcher.category, "appearance", [Layout.placed("layout.launcher.host", "prefs.layout.opens_in")]),
    // the widgets: one card (the switch, the list with add / remove and one
    // "Arrange on desktop", the surface and layering, then the icons); the
    // clock: its switch, style and details in one card
    mergeInto(moveEntry(mergeInto(Desktop.category, "arrange", ["icons", "icondetails"]), "desktop.depthClock", "clock"), "clock", ["clockmore"]),
    mergeInto(Lockscreen.category, "style", ["tone"]),
    mergeInto(Notifications.category, "behaviour", ["sound", "history"]),
    withSections(withEntries(Menus.category, "menus", [Layout.placed("layout.sheet.side", "prefs.layout.sheet_side"), Layout.placed("layout.backdrop", "prefs.layout.backdrop")], "layout.tools.style"), Osd.sections),
    mergeInto(withEntries(Dashboard.category, "", [Layout.placed("layout.dashboard.host", "prefs.layout.opens_in")]), "home", ["memory"]),
    Specials.category,
    mergeInto(mergeInto(mergeInto(Windows.category, "unfocused", ["dim"]), "borders", ["pulse"]), "blur", ["shadows"]),
    mergeInto(mergeInto(Terminal.category, "look", ["engine"]), "kitty", ["terminal"]),
    withEntries(Input.category, "", [Layout.placed("layout.cheatsheet.host", "prefs.layout.sheet_opens_in")]),
    // OCR languages are a language setting: Language & weather, not Updates
    withSections(System.category, sectionsOf(Updates.category, ["ocr"])),
    Voice.category,
    withEntries(Timers.category, "notch", [Layout.placed("layout.panels.host", "prefs.layout.opens_in")]),
    Routines.category,
    withoutSections(Updates.category, ["ocr"]),
    Power.category,
    Network.category,
    Bluetooth.category,
    Sound.category,
    Effects.category,
    mergeInto(mergeInto(withEntries(withSections(Ai.category, Sidebar.sections), "quickask", [Layout.placed("layout.aiquick.host", "prefs.layout.quickask_opens_in")], "ai.quickAsk.enabled"), "center", ["model_effort", "context"]), "bar_behavior", ["sidebar"]),
    AiProviders.category,
    AiCode.category,
    Object.assign(page("mods", "puzzlePiece", "Mods", "mods extensions plugins modifications install"), {
        "form": "list",
        "row": ["mods_list", "mods_details"]
    }),
    page("changes", "listChecks", "Changes", "changes changed modified differences diff what did i change reset defaults preset custom", true),
    {
        "id": "presets",
        "icon": "magicWand",
        "title": "prefs.cat.presets",
        "description": "prefs.cat.presets.desc",
        "keywords": "presets studio save load profiles themes layouts looks gallery mixer mix duplicate import export share try",
        "page": "PresetStudio",
        "row": ["presets_saving"],
        "sections": Presets.sections
    },
    {
        "id": "displays",
        "icon": "monitor",
        "title": "prefs.cat.displays",
        "description": "prefs.cat.displays.desc",
        "keywords": "displays monitors screens resolution refresh rate hz scale dpi rotation rotate arrange layout position vrr adaptive sync identify hdmi displayport",
        "page": "Displays",
        "fitted": true
    },
    {
        "id": "keyboard",
        "icon": "keyboard",
        "title": "prefs.cat.keyboard",
        "description": "prefs.cat.keyboard.desc",
        "keywords": "keyboard layout layouts language russian english variant switch alt shift caps lock escape ctrl compose xkb options key repeat rate delay indicator type typing",
        "page": "Keyboard",
        "fitted": true
    },
    {
        "id": "extras",
        "icon": "packageBox",
        "title": "prefs.cat.extras",
        "description": "prefs.cat.extras.desc",
        "keywords": "apps extras install software packages catalog browsers chat games steam discord spotify media ai agents claude codex ollama cuda voice flatpak aur terminal fish starship",
        "page": "Extras",
        "form": "list",
        "row": ["catalog"]
    },
    {
        "id": "about",
        "icon": "info",
        "title": "prefs.cat.about",
        "description": "prefs.cat.about.desc",
        "keywords": "about version credits license notice yozakura",
        "page": "AboutPage",
        "fitted": true
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

// The tabs of the destination holding `categoryId`: [category...] (one tab
// = no tab strip).
function tabsOf(categoryId) {
    var g = groupOf(categoryId);
    return g ? g.categories.map(byId).filter(function (c) {
        return c !== null;
    }) : [];
}

// Home model: the tiles as destinations.
function home() {
    return HOME.map(function (t) {
        return groupById(t.id);
    });
}

// Categories in destination order (Ctrl+Tab steps through them).
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
