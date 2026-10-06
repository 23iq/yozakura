.pragma library

// Which surface shows a module. `layout` is Config.layout; `vis` is a
// Visibilities per-screen object. The Visibilities flags keep meaning "this
// module is open on this screen"; the router only decides where it shows.

var HOSTS = ["notch", "spotlight", "sheet"];
// Modules that can leave the notch (layout.<module>.host).
var ROUTABLE = ["launcher", "dashboard"];
// Modules the notch shows unless their layout.<module>.style moves them to
// the menu overlay (modules/widgets/menus/MenuOverlay.qml).
var NOTCH_ONLY = ["powermenu", "tools", "aiquick"];
// layout.<module>.style values; the first is the notch default.
var MENU_STYLES = {
    "powermenu": ["notch", "fullscreen", "radial"],
    "tools": ["notch", "radial"]
};
// layout.cheatsheet.host values; the first is the default.
var CHEATSHEET_HOSTS = ["fullscreen", "spotlight", "sheet"];
// Visibilities flag of a module when it differs from the module name.
var FLAGS = {
    "cheatsheet": "keybinds"
};
var MODULES = ROUTABLE.concat(["cheatsheet"], NOTCH_ONLY);

function isKnown(host) {
    return HOSTS.indexOf(host) !== -1;
}

function flagOf(module) {
    return FLAGS[module] || module;
}

function _value(layout, module, key) {
    var cfg = layout ? layout[module] : null;
    return cfg ? cfg[key] : undefined;
}

// The style of a menu module ("notch" when unknown or not a menu).
function menuStyle(layout, module) {
    var styles = MENU_STYLES[module];
    if (!styles)
        return "notch";
    var style = _value(layout, module, "style");
    return styles.indexOf(style) !== -1 ? style : "notch";
}

function hostFor(layout, module) {
    if (module === "cheatsheet") {
        var c = _value(layout, module, "host");
        return CHEATSHEET_HOSTS.indexOf(c) !== -1 ? c : CHEATSHEET_HOSTS[0];
    }
    if (MENU_STYLES[module])
        return menuStyle(layout, module) === "notch" ? "notch" : "overlay";
    if (ROUTABLE.indexOf(module) === -1)
        return "notch";
    var host = _value(layout, module, "host");
    return isKnown(host) ? host : "notch";
}

// The open module routed to `host`, or "".
function moduleIn(vis, layout, host) {
    if (!vis)
        return "";
    for (var i = 0; i < MODULES.length; i++) {
        var m = MODULES[i];
        if (vis[flagOf(m)] && hostFor(layout, m) === host)
            return m;
    }
    return "";
}

// Whether the notch expands for the open modules.
function notchOpen(vis, layout) {
    return moduleIn(vis, layout, "notch") !== "";
}
