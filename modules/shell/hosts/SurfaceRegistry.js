.pragma library

// Surfaces (what opens) and hosts (where it shows). A surface reads one
// layout key; "auto" (and an unknown value) walks its `auto` chain, the
// first available host wins (HostResolve.js). Nothing here writes config.

// Hosts. `needsNotch`: only while notch.enabled. `built: false`: not
// implemented yet, `standIn` shows instead (none today).
var HOSTS = {
    "notch": {
        "needsNotch": true
    },
    "spotlight": {},
    "sheet": {},
    // Menu overlay styles (modules/widgets/menus/MenuOverlay.qml)
    "fullscreen": {},
    "radial": {},
    // Small floating card beside the bar (CardHost.qml, EdgeService.cardRect)
    "card": {}
};

// Surfaces: `key` under Config.layout, `allowed` = its explicit values
// (besides "auto"), `auto` = the chain "auto" resolves through.
var SURFACES = {
    "launcher": {
        "key": "launcher.host",
        "allowed": ["notch", "spotlight", "sheet"],
        "auto": ["notch", "spotlight"]
    },
    "dashboard": {
        "key": "dashboard.host",
        "allowed": ["notch", "spotlight", "sheet"],
        "auto": ["notch", "sheet"]
    },
    "powermenu": {
        "key": "powermenu.style",
        "allowed": ["notch", "fullscreen", "radial"],
        "auto": ["notch", "fullscreen"]
    },
    "tools": {
        "key": "tools.style",
        "allowed": ["notch", "radial"],
        "auto": ["notch", "radial"]
    },
    // Never in the notch; no "auto" value in its config
    "cheatsheet": {
        "key": "cheatsheet.host",
        "allowed": ["fullscreen", "spotlight", "sheet"],
        "auto": ["fullscreen"]
    },
    // AI quick ask (HostedSurfaces off the notch)
    "aiquick": {
        "key": "aiquick.host",
        "allowed": ["notch", "card", "spotlight"],
        "auto": ["notch", "card"]
    },
    // Notch auto panels (voice, timer hub, alarm; PanelSurfaces off the notch)
    "panels": {
        "key": "panels.host",
        "allowed": ["notch", "card"],
        "auto": ["notch", "card"]
    }
};

function surface(id) {
    return SURFACES[id] || null;
}

function host(id) {
    return HOSTS[id] || null;
}
