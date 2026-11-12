.pragma library
.import "schema/Categories.js" as Categories
.import "../lockscreen/styles/LockStyleRegistry.js" as LockStyles

// The one live status line under a home tile ("Dark · Ink · Tonal spot",
// "Top bar · island · dock", "Glass", "12 in your library"). Pure,
// node-tested (tests/settings-home.test.cjs).
// ctx = {get(key), tr(i18nKey), wallpapers: number, preset: string}

// Destinations with a fixed line of what they hold (prefs.home.sub.<id>).
var SUBTITLED = ["launcher", "dashboard", "desktop", "keys", "displays", "assistant", "system"];

// Fallback: what the destination holds, else its first tabs.
function tabsLine(dest, tr) {
    if (SUBTITLED.indexOf(dest) >= 0)
        return tr("prefs.home.sub." + dest);
    var g = Categories.groupById(dest);
    if (!g)
        return "";
    var names = g.categories.slice(0, 2).map(function (id) {
        var c = Categories.byId(id);
        return c ? tr(c.title) : "";
    });
    return names.join(", ");
}

function layout(ctx) {
    var panels = ctx.get("bar.panels") || [];
    var bars = panels.length > 1 ? ctx.tr("prefs.home.bars").replace("%1", panels.length) : ctx.tr("prefs.home.edge." + (ctx.get("bar.position") || "top"));
    var parts = [bars];
    if (ctx.get("notch.enabled") !== false)
        parts.push(ctx.tr("prefs.home.island"));
    if (ctx.get("dock.enabled") !== false && ctx.get("dock.theme") !== "integrated")
        parts.push(ctx.tr("prefs.home.dock"));
    return parts.join(" · ");
}

function look(ctx) {
    var mode = ctx.get("theme.lightMode") === true ? "light" : (ctx.get("theme.oledMode") === true ? "oled" : "dark");
    var lang = ctx.get("theme.language") || "ink";
    var scheme = String(ctx.get("wallpaper.matugenScheme") || "scheme-tonal-spot").replace(/-/g, "_");
    return [ctx.tr("prefs.appearance.mode." + mode), ctx.tr("prefs.appearance.language." + lang), ctx.tr("wallpapers." + scheme)].join(" · ");
}

function line(dest, ctx) {
    switch (dest) {
    case "layout":
        return layout(ctx);
    case "look":
        return look(ctx);
    case "wallpaper":
        return ctx.wallpapers > 0 ? ctx.tr("prefs.home.library").replace("%1", ctx.wallpapers) : ctx.tr("prefs.home.sub.wallpaper");
    case "presets":
        return ctx.preset ? ctx.preset : ctx.tr("prefs.home.custom");
    case "notifications":
        {
            var pres = ctx.get("notifications.presentation") || "auto";
            if (pres === "notch")
                return ctx.tr("prefs.home.in_island");
            var pos = ctx.get("notifications.position") || "auto";
            return pos === "auto" ? ctx.tr("prefs.notif.presentation." + pres) : ctx.tr("prefs.notif.position." + pos);
        }
    case "lockscreen":
        {
            var st = LockStyles.get(ctx.get("lockscreen.style") || LockStyles.DEFAULT_ID);
            return st ? ctx.tr(st.labelKey) : "";
        }
    case "windows":
        return ctx.tr("prefs.home.gaps").replace("%1", ctx.get("compositor.gapsIn") ?? 0);
    default:
        return tabsLine(dest, ctx.tr);
    }
}
