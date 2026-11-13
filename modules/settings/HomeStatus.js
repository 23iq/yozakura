.pragma library
.import "schema/Categories.js" as Categories
.import "../lockscreen/styles/LockStyleRegistry.js" as LockStyles
.import "../notifications/NotificationPolicy.js" as Policy

// The one live status line under a home tile ("Dark · Ink · Tonal spot",
// "Top bar · island · dock", "Glass", "12 in your library"). Pure,
// node-tested (tests/settings-home.test.cjs).
// ctx = {get(key), tr(i18nKey), wallpapers: number, preset: string,
//        outputs: [{width, height, refresh, enabled}], network: string,
//        volume: 0..1.5 (-1 none), language: string, update: bool}
//        (all optional)

// Destinations with a fixed line of what they hold (prefs.home.sub.<id>).
var SUBTITLED = ["panels", "keys", "devices", "assistant", "system"];

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

function displays(ctx) {
    var on = (ctx.outputs || []).filter(function (o) {
        return o && o.enabled !== false && o.width > 0;
    });
    if (on.length === 0)
        return "";
    var o = on[0];
    return o.width + "×" + o.height + (o.refresh > 0 ? " · " + Math.round(o.refresh) + " Hz" : "") + (on.length > 1 ? " · +" + (on.length - 1) : "");
}

function line(dest, ctx) {
    switch (dest) {
    case "screen":
        return layout(ctx);
    case "look":
        return look(ctx) + (ctx.preset ? " · " + ctx.preset : "");
    case "panels":
        {
            var host = ctx.get("layout.launcher.host") || "auto";
            return ctx.tr("prefs.home.launcher_in").replace("%1", ctx.tr(host === "auto" ? "common.auto" : "prefs.layout.host." + host));
        }
    case "notifications":
        {
            if (ctx.get("notifications.dnd.enabled") === true)
                return ctx.tr("prefs.home.dnd_on");
            var pres = ctx.get("notifications.presentation") || "auto";
            if (pres === "notch")
                return ctx.tr("prefs.home.in_island");
            // where they show now: an "auto" corner resolved as the shell does
            var pos = Policy.resolvePosition(ctx.get("notifications.position") || "auto", {
                "barPosition": ctx.get("bar.position") || "top"
            });
            return ctx.tr("prefs.notif.position." + pos);
        }
    case "windows":
        return ctx.tr("prefs.home.gaps_border").replace("%1", ctx.get("compositor.gapsIn") ?? 0).replace("%2", ctx.get("compositor.borderSize") ?? 0);
    case "keys":
        {
            var layouts = (ctx.get("keyboard.layouts") || []).map(function (l) {
                return String(l && l.layout || "").toUpperCase();
            }).filter(function (l) {
                return l !== "";
            });
            return layouts.length > 0 ? ctx.tr("prefs.home.sub.keys") + " · " + layouts.join(", ") : tabsLine(dest, ctx.tr);
        }
    case "devices":
        {
            var parts = [];
            if (ctx.network)
                parts.push(ctx.network);
            if (typeof ctx.volume === "number" && ctx.volume >= 0)
                parts.push(ctx.tr("prefs.home.volume").replace("%1", Math.round(ctx.volume * 100)));
            var d = displays(ctx);
            if (d)
                parts.push(d);
            return parts.length > 0 ? parts.join(" · ") : tabsLine(dest, ctx.tr);
        }
    case "system":
        {
            var sys = [];
            if (ctx.language)
                sys.push(ctx.language);
            sys.push(ctx.tr(ctx.update ? "prefs.home.update" : "prefs.home.uptodate"));
            return sys.join(" · ");
        }
    default:
        return tabsLine(dest, ctx.tr);
    }
}
