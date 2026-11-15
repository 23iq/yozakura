.pragma library

// Sample data of the launcher previews (LauncherStage, LauncherStyleThumb):
// what the real launcher (LauncherView with a PreviewContext) shows for a
// believable search. The apps provider stays live (your installed apps,
// searched in memory); the providers that would run something (files,
// commands, the AI...) answer with one sample row each, in the configured
// order. Row fields are LauncherProvider's; `icon` is an Icons name, the
// `...Key` fields are i18n keys (UI words are translated; names of files
// and sums are data), a title of "$query" is the query itself (the AI row
// asks it) and `titleFormat` holds the translated title as "{}"; a badge is
// what you would type: your prefix of that provider (`badgePrefix`, the
// row has none when you have none) and `badgeArg`.
// Pure; tests/settings-launcher-samples.test.cjs.

var ROWS = {
    "calculator": {
        "title": "12 × 4 = 48",
        "subtitleKey": "launcher.provider.calculator",
        "icon": "calculator",
        "hintKey": "launcher.copy",
        "emphasis": true
    },
    "commands": {
        "titleKey": "launcher.cmd.dnd",
        "subtitleKey": "launcher.provider.commands",
        "icon": "bellSlash",
        "badgePrefix": "commands",
        "badgeArg": "dnd",
        "hintKey": "launcher.run"
    },
    "timers": {
        "titleKey": "focus.timer_name",
        "titleFormat": "10:00 · {}",
        "subtitleKey": "launcher.provider.timers",
        "icon": "timer",
        "badgePrefix": "timers",
        "badgeArg": "10m",
        "hintKey": "launcher.run"
    },
    "specials": {
        "titleKey": "focus.title",
        "subtitleKey": "launcher.provider.specials",
        "icon": "cube",
        "hintKey": "specials.launcher.hint"
    },
    "routines": {
        "titleKey": "prefs.timers.section.focus",
        "subtitleKey": "launcher.provider.routines",
        "icon": "lightning",
        "badgePrefix": "routines",
        "badgeArg": "focus",
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
// `glyph(name)` maps an Icons name to its glyph, `prefix(providerId)` is
// your prefix of that provider (Config.prefix; none: no badge).
function title(r, q, t) {
    if (r.title === "$query")
        return q;
    if (!r.titleKey)
        return r.title;
    var word = t(r.titleKey);
    return r.titleFormat ? r.titleFormat.replace("{}", word) : word;
}
function badge(r, t, prefix) {
    if (r.badgeKey)
        return t(r.badgeKey);
    if (!r.badgePrefix)
        return r.badge || "";
    var p = typeof prefix === "function" ? String(prefix(r.badgePrefix) || "") : "";
    return p ? p + " " + r.badgeArg : "";
}
function rows(style, q, t, glyph, prefix) {
    var out = {};
    if (style === "grid")
        return out;
    Object.keys(ROWS).forEach(function (id) {
        var r = ROWS[id];
        out[id] = [{
                "key": "sample-" + id,
                "title": title(r, q, t),
                "subtitle": r.subtitleKey ? t(r.subtitleKey) : (r.subtitle || ""),
                "icon": glyph(r.icon),
                "badge": badge(r, t, prefix),
                "hint": t(r.hintKey),
                "emphasis": r.emphasis === true
            }];
    });
    return out;
}
