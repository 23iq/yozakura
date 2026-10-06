.pragma library

// Which surface shows a module. `layout` is Config.layout; `vis` is a
// Visibilities per-screen object. The Visibilities flags keep meaning "this
// module is open on this screen"; the router only decides where it shows.

var HOSTS = ["notch", "spotlight", "sheet"];
// Modules that can leave the notch (layout.<module>.host).
var ROUTABLE = ["launcher", "dashboard"];
// Modules the notch shows whatever the layout says.
var NOTCH_ONLY = ["powermenu", "tools", "aiquick"];

function isKnown(host) {
    return HOSTS.indexOf(host) !== -1;
}

function hostFor(layout, module) {
    if (ROUTABLE.indexOf(module) === -1)
        return "notch";
    var cfg = layout ? layout[module] : null;
    var host = cfg ? cfg.host : undefined;
    return isKnown(host) ? host : "notch";
}

// The open module routed to `host`, or "".
function moduleIn(vis, layout, host) {
    if (!vis)
        return "";
    for (var i = 0; i < ROUTABLE.length; i++) {
        var m = ROUTABLE[i];
        if (vis[m] && hostFor(layout, m) === host)
            return m;
    }
    if (host === "notch") {
        for (var j = 0; j < NOTCH_ONLY.length; j++) {
            if (vis[NOTCH_ONLY[j]])
                return NOTCH_ONLY[j];
        }
    }
    return "";
}

// Whether the notch expands for the open modules.
function notchOpen(vis, layout) {
    return moduleIn(vis, layout, "notch") !== "";
}
