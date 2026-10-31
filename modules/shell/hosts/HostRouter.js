.pragma library
.import "HostResolve.js" as Resolve
.import "SurfaceRegistry.js" as Registry

// Which surface shows a module. `layout` is Config.layout; `vis` is a
// Visibilities per-screen object; `ctx` the HostResolve context
// ({notchEnabled, barEnabled, barEdges}; omitted = notch on). The
// Visibilities flags keep meaning "this module is open on this screen"; the
// router only decides where it shows (HostResolve.js picks the host).

var HOSTS = ["notch", "spotlight", "sheet"];
// Modules that can leave the notch (layout.<module>.host); aiquick also
// opens in a floating card.
var ROUTABLE = ["launcher", "dashboard", "aiquick"];
// Modules the notch shows unless their layout.<module>.style moves them to
// the menu overlay (modules/widgets/menus/MenuOverlay.qml).
var NOTCH_ONLY = ["powermenu", "tools"];
// layout.<module>.style values besides "auto"; the first is the notch.
var MENU_STYLES = {
    "powermenu": Registry.SURFACES.powermenu.allowed,
    "tools": Registry.SURFACES.tools.allowed
};
// layout.cheatsheet.host values; the first is the default.
var CHEATSHEET_HOSTS = Registry.SURFACES.cheatsheet.allowed;
// Visibilities flag of a module when it differs from the module name.
var FLAGS = {
    "cheatsheet": "keybinds"
};
var MODULES = ROUTABLE.concat(["cheatsheet"], NOTCH_ONLY);

// A value layout.launcher/dashboard.host understands ("auto" included).
function isKnown(host) {
    return host === "auto" || HOSTS.indexOf(host) !== -1;
}

function flagOf(module) {
    return FLAGS[module] || module;
}

// The resolved style of a menu module ("notch" when not a menu).
function menuStyle(layout, module, ctx) {
    if (!MENU_STYLES[module])
        return "notch";
    return Resolve.resolve(layout, module, ctx);
}

// The host of a module, or of "panels" (the notch's auto panels: voice,
// timer hub, alarm; PanelSurfaces.qml off the notch).
function hostFor(layout, module, ctx) {
    if (module === "cheatsheet" || module === "panels" || ROUTABLE.indexOf(module) !== -1)
        return Resolve.resolve(layout, module, ctx);
    if (MENU_STYLES[module])
        return menuStyle(layout, module, ctx) === "notch" ? "notch" : "overlay";
    return "notch";
}

// The open module routed to `host`, or "".
function moduleIn(vis, layout, host, ctx) {
    if (!vis)
        return "";
    for (var i = 0; i < MODULES.length; i++) {
        var m = MODULES[i];
        if (vis[flagOf(m)] && hostFor(layout, m, ctx) === host)
            return m;
    }
    return "";
}

// Whether the notch expands for the open modules.
function notchOpen(vis, layout, ctx) {
    return moduleIn(vis, layout, "notch", ctx) !== "";
}
