.pragma library

// Pure geometry of the Launcher and Dashboard stages: where a surface that
// opens in a host (HostResolve: "notch" | "spotlight" | "sheet") sits on the
// screen miniature, drawn large enough to read (node-tested in
// tests/settings-surface-place.test.cjs).
//   free    ScreenMini.freeRect {x, y, w, h}
//   island  ScreenMini.islandRect {x, y, w, h}
//   opts    {islandEdge: "top" | "bottom", sheetSide: "left" | "right",
//            wide: bool (the dashboard: a wider box)}
// -> {x, y, w, h, from: "island" | "center" | "left" | "right"}
function rect(host, free, island, opts) {
    var o = opts || {};
    var wide = !!o.wide;
    var w, h;
    if (host === "sheet") {
        w = free.w * (wide ? 0.42 : 0.34);
        var left = o.sheetSide === "left";
        return {
            "x": left ? free.x : free.x + free.w - w,
            "y": free.y,
            "w": w,
            "h": free.h,
            "from": left ? "left" : "right"
        };
    }
    w = free.w * (wide ? 0.66 : 0.54);
    h = free.h * (wide ? 0.8 : 0.78);
    if (host === "notch" && island && island.w > 0) {
        var cx = island.x + island.w / 2;
        var x = Math.max(free.x, Math.min(cx - w / 2, free.x + free.w - w));
        var bottom = o.islandEdge === "bottom";
        return {
            "x": x,
            "y": bottom ? island.y + island.h - h : island.y,
            "w": w,
            "h": h,
            "from": "island"
        };
    }
    return {
        "x": free.x + (free.w - w) / 2,
        "y": free.y + (free.h - h) / 2,
        "w": w,
        "h": h,
        "from": "center"
    };
}

// A launcher result for each provider: [icon, title, detail] (the stage's
// sample query "fi"); titles that are not names are i18n keys.
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
