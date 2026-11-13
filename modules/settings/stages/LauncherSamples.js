.pragma library

// Sample results of the launcher providers for the Launcher stage: one row
// per provider (icon, title, detail key), the query being "fi".

var SAMPLES = {
    "apps": ["apps", "Firefox", "launcher.provider.apps"],
    "calculator": ["calculator", "12 × 4 = 48", "launcher.provider.calculator"],
    "commands": ["command", "> dnd", "launcher.provider.commands"],
    "timers": ["timer", "t 10m tea", "launcher.provider.timers"],
    "specials": ["cube", "music", "launcher.provider.specials"],
    "routines": ["lightning", "@ focus", "launcher.provider.routines"],
    "wallpapers": ["image", "sakura.png", "launcher.provider.wallpapers"],
    "files": ["folder", "~/Documents/final.pdf", "launcher.provider.files"],
    "ai": ["sparkle", "fi", "launcher.provider.ai"]
};

// The sample rows of the active providers, in order, at most `max`.
function results(active, max) {
    var out = [];
    for (var i = 0; i < (active || []).length && out.length < max; i++) {
        var s = SAMPLES[active[i]];
        if (s)
            out.push({
                "id": active[i],
                "icon": s[0],
                "title": s[1],
                "detail": s[2]
            });
    }
    return out;
}
