.pragma library

// Sample data of the launcher previews (LauncherStage, LauncherStyleThumb):
// what the real launcher (LauncherView with a PreviewContext) shows for a
// believable search. The apps provider stays live (your installed apps,
// searched in memory); the providers that would run something (files,
// commands, the AI...) answer with one sample row each, in the configured
// order. Row fields are LauncherProvider's; `icon` is an Icons name, the
// `...Key` fields are i18n keys and a title of "$query" is the query
// itself (the AI row asks it). Pure; tests/settings-launcher-samples.test.cjs.

var ROWS = {
    "calculator": {
        "title": "12 × 4 = 48",
        "subtitleKey": "launcher.provider.calculator",
        "icon": "calculator",
        "hintKey": "launcher.copy",
        "emphasis": true
    },
    "commands": {
        "title": "Do not disturb",
        "subtitleKey": "launcher.provider.commands",
        "icon": "bellSlash",
        "badge": "> dnd",
        "hintKey": "launcher.run"
    },
    "timers": {
        "title": "10 min · tea",
        "subtitleKey": "launcher.provider.timers",
        "icon": "timer",
        "badge": "t 10m tea",
        "hintKey": "launcher.run"
    },
    "specials": {
        "title": "Focus",
        "subtitleKey": "launcher.provider.specials",
        "icon": "cube",
        "hintKey": "specials.launcher.hint"
    },
    "routines": {
        "title": "Focus mode",
        "subtitleKey": "launcher.provider.routines",
        "icon": "lightning",
        "badge": "@ focus",
        "hintKey": "launcher.run"
    },
    "wallpapers": {
        "title": "sakura-night.png",
        "subtitleKey": "launcher.provider.wallpapers",
        "icon": "image",
        "hintKey": "launcher.wall.set"
    },
    "files": {
        "title": "final-draft.pdf",
        "subtitle": "~/Documents/final-draft.pdf",
        "icon": "fileText",
        "hintKey": "launcher.open"
    },
    "ai": {
        "title": "$query",
        "subtitleKey": "launcher.ai.ask",
        "icon": "sparkle",
        "badgeKey": "launcher.provider.ai",
        "hintKey": "launcher.ai.send"
    }
};

// The providers that stay live in a preview (no I/O, nothing runs).
var LIVE = ["apps"];

// The query typed in a preview: the first two letters of your first app
// (so the live apps provider has matches), "fi" without apps. A grid only
// shows apps, which a real launcher does on an empty search: "".
function query(appNames, style) {
    if (style === "grid")
        return "";
    var names = appNames || [];
    for (var i = 0; i < names.length; i++) {
        var n = typeof names[i] === "string" ? names[i].trim() : "";
        if (n.length >= 2)
            return n.slice(0, 2).toLowerCase();
    }
    return "fi";
}

// {providerId: [row]}: one row per provider with a sample (none for a
// grid: an empty search lists the apps only). `t(key)` translates,
// `glyph(name)` maps an Icons name to its glyph.
function rows(style, q, t, glyph) {
    var out = {};
    if (style === "grid")
        return out;
    Object.keys(ROWS).forEach(function (id) {
        var r = ROWS[id];
        out[id] = [{
                "key": "sample-" + id,
                "title": r.title === "$query" ? q : r.title,
                "subtitle": r.subtitleKey ? t(r.subtitleKey) : (r.subtitle || ""),
                "icon": glyph(r.icon),
                "badge": r.badgeKey ? t(r.badgeKey) : (r.badge || ""),
                "hint": t(r.hintKey),
                "emphasis": r.emphasis === true
            }];
    });
    return out;
}
