.pragma library
.import "schema/Categories.js" as Categories
.import "../lockscreen/styles/LockStyleRegistry.js" as LockStyles
.import "../notifications/NotificationPolicy.js" as Policy
.import "../shell/hosts/HostResolve.js" as HostResolve
.import "../services/ai/Providers.js" as Providers

// The one live status line under a home tile: what the destination does
// now, in a few words that fit one line at every tile size ("Dark · Ink ·
// Tonal spot", "Top bar · island · dock", "Spotlight launcher", "Corner
// toasts · top right", "Ollama · llama3", "English (US), Russian",
// "English (US) · up to date"). Pure, node-tested (tests/settings-home.test.cjs).
// ctx = {get(key), tr(i18nKey), wallpapers: number, preset: string,
//        outputs: [{width, height, refresh, enabled}], network: string,
//        volume: 0..1.5 (-1 none), language: string, update: bool,
//        version: string, layoutName(code) -> "English (US)" | ""}
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

// The first bar panel's edge and style (bar.panels, else the legacy keys).
function firstBar(ctx) {
    var panels = ctx.get("bar.panels") || [];
    var p = panels[0] || {};
    return {
        "edge": p.edge || ctx.get("bar.position") || "top",
        "style": p.style || ""
    };
}

function layout(ctx) {
    var panels = ctx.get("bar.panels") || [];
    var bars = panels.length > 1 ? ctx.tr("prefs.home.bars").replace("%1", panels.length) : ctx.tr("prefs.home.edge." + firstBar(ctx).edge);
    // every part named, the ones that are off too ("dock off"): the line
    // says what the miniature beside it shows
    var parts = [bars];
    parts.push(ctx.tr(ctx.get("notch.enabled") !== false ? "prefs.home.island" : "prefs.home.island_off"));
    if (ctx.get("dock.enabled") === false)
        parts.push(ctx.tr("prefs.home.dock_off"));
    else if (ctx.get("dock.theme") === "integrated")
        parts.push(ctx.tr("prefs.home.dock_in_bar"));
    else
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

// Where the launcher opens now ("auto" resolved as the shell does):
// "notch" | "spotlight" | "sheet".
function launcherHost(ctx) {
    return HostResolve.resolve({
        "launcher": {
            "host": ctx.get("layout.launcher.host") || "auto"
        }
    }, "launcher", {
        "notchEnabled": ctx.get("notch.enabled") !== false
    });
}

function panels(ctx) {
    return ctx.tr("prefs.home.launcher_style").replace("%1", ctx.tr("prefs.layout.host." + launcherHost(ctx)));
}

// How and where notifications show now ("auto" resolved as the shell
// does): {dnd, presentation: "notch" | "strips" | "corner", position:
// "top-right" | ...}.
function notificationState(ctx) {
    var bar = firstBar(ctx);
    var pres = Policy.resolvePresentation(ctx.get("notifications.presentation") || "auto", {
        "barStyle": bar.style,
        "barPosition": bar.edge,
        "notchPosition": ctx.get("notch.position") || "top",
        "notchEnabled": ctx.get("notch.enabled") !== false
    });
    return {
        "dnd": ctx.get("notifications.dnd.enabled") === true,
        "presentation": pres === "notch" || pres === "strips" ? pres : "corner",
        "position": Policy.resolvePosition(ctx.get("notifications.position") || "auto", {
            "barPosition": bar.edge
        })
    };
}

function notifications(ctx) {
    var n = notificationState(ctx);
    if (n.dnd)
        return ctx.tr("prefs.home.dnd_on");
    if (n.presentation === "notch")
        return ctx.tr("prefs.home.in_island");
    if (n.presentation === "strips")
        return ctx.tr("prefs.home.toasts_strips");
    return ctx.tr("prefs.home.toasts_corner").replace("%1", ctx.tr("prefs.notif.position." + n.position).toLowerCase());
}

// The layouts by name ("English (US), Russian"); their codes until the
// catalog is there.
function keys(ctx) {
    var names = (ctx.get("keyboard.layouts") || []).map(function (l) {
        var code = String(l && l.layout || "");
        return (ctx.layoutName && code ? ctx.layoutName(code) : "") || code.toUpperCase();
    }).filter(function (l) {
        return l !== "";
    });
    return names.length > 0 ? names.join(", ") : tabsLine("keys", ctx.tr);
}

function devices(ctx) {
    var parts = [];
    if (ctx.network)
        parts.push(ctx.network);
    if (typeof ctx.volume === "number" && ctx.volume >= 0)
        parts.push(ctx.tr("prefs.home.volume").replace("%1", Math.round(ctx.volume * 100)));
    // the monitors only when there is nothing else to say (one short line)
    var d = displays(ctx);
    if (d && parts.length === 0)
        parts.push(d);
    return parts.length > 0 ? parts.join(" · ") : tabsLine("devices", ctx.tr);
}

// "Ollama · llama3.2": the default model's provider and model (model ids
// are "provider:model"); "Ready to chat" without one; "Off".
function assistant(ctx) {
    if (ctx.get("ai.enabled") === false)
        return ctx.tr("common.off");
    var id = String(ctx.get("ai.defaultModel") || "");
    if (id === "")
        return ctx.tr("prefs.home.ai_ready");
    var at = id.indexOf(":");
    if (at < 0)
        return id;
    var p = Providers.PROVIDERS[id.slice(0, at)];
    var model = id.slice(at + 1);
    return p ? p.label + " · " + model : model;
}

function capital(s) {
    return s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
}

// "English (US) · up to date": the UI language and the update state (the
// version where the language is unknown; the System scene prints the
// version itself).
function system(ctx) {
    var sys = [];
    if (ctx.language)
        sys.push(ctx.language);
    else if (ctx.version && ctx.version !== "0.0.0")
        sys.push(ctx.version);
    sys.push(ctx.tr(ctx.update ? "prefs.home.update" : "prefs.home.uptodate"));
    // "up to date" is a mid-line phrase; leading the line it starts
    // with a capital
    return capital(sys.join(" · "));
}

// The line as it fits `width` (measure(text) -> px): its last " · " parts
// drop until it does, so it stays one line of whole words in any language
// and tile size ("Top bar · island · dock" -> "Top bar · island"); a single
// part that is still too wide is left to elide (data: a network name).
function fit(text, measure, width) {
    var parts = String(text || "").split(" · ");
    while (parts.length > 1 && measure(parts.join(" · ")) > width)
        parts.pop();
    return parts.join(" · ");
}

function line(dest, ctx) {
    switch (dest) {
    case "screen":
        return layout(ctx);
    case "look":
        return look(ctx) + (ctx.preset ? " · " + ctx.preset : "");
    case "panels":
        return panels(ctx);
    case "notifications":
        return notifications(ctx);
    case "windows":
        return ctx.tr("prefs.home.gaps_border").replace("%1", ctx.get("compositor.gapsIn") ?? 0).replace("%2", ctx.get("compositor.borderSize") ?? 0);
    case "keys":
        return keys(ctx);
    case "devices":
        return devices(ctx);
    case "assistant":
        return assistant(ctx);
    case "system":
        return system(ctx);
    default:
        return tabsLine(dest, ctx.tr);
    }
}
