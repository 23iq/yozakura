.pragma library

// Panel style registry. A style is one component under styles/ that lays a
// panel's groups out along its edge (see styles/PanelStyleBase.qml for the
// contract) + one entry here. Adding a style = one file + one entry + its
// label translations.
//
//  file         component, relative to modules/bar/panels/
//  edges        edges the style supports (the first is its natural one)
//  groups       groups the style renders (the settings editor shows these)
//  flat         modules drop their own pill background by default
//  size         default module size in px (0 = BarMetrics.moduleSize)
//  containable  `bar.containBar` can swallow the panel into the frame
//  activity     how live activities attach next to a notch on the same edge:
//               "tab" (notch-like tabs) or "pill" (rounded pills)
//  floating     detached from the screen edge (dock)
var ALL_EDGES = ["top", "bottom", "left", "right"];
var GROUPS = ["start", "center", "end", "drawer", "gapStart", "gapEnd"];

var STYLES = [
    {
        "id": "classic",
        "file": "styles/ClassicPanel.qml",
        "icon": "alignJustify",
        "label": "prefs.bar.style.classic",
        "desc": "prefs.bar.style.classic.desc",
        "edges": ALL_EDGES,
        "groups": ["start", "center", "end", "drawer", "gapStart", "gapEnd"],
        "flat": false,
        "size": 0,
        "containable": true,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "islands",
        "file": "styles/IslandsPanel.qml",
        "icon": "dotsThree",
        "label": "prefs.bar.style.islands",
        "desc": "prefs.bar.style.islands.desc",
        "edges": ALL_EDGES,
        "groups": ["start", "center", "end", "drawer", "gapStart", "gapEnd"],
        "flat": false,
        "size": 0,
        "containable": false,
        "activity": "tab",
        "floating": false
    },
    {
        "id": "menubar",
        "file": "styles/MenubarPanel.qml",
        "icon": "list",
        "label": "prefs.bar.style.menubar",
        "desc": "prefs.bar.style.menubar.desc",
        "edges": ["top", "bottom"],
        "groups": ["start", "center", "end", "drawer"],
        "flat": true,
        "size": 26,
        "containable": true,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "statusline",
        "file": "styles/StatuslinePanel.qml",
        "icon": "terminalWindow",
        "label": "prefs.bar.style.statusline",
        "desc": "prefs.bar.style.statusline.desc",
        "edges": ["bottom", "top"],
        "groups": ["start", "center", "end"],
        "flat": true,
        "size": 24,
        "containable": true,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "ribbon",
        "file": "styles/RibbonPanel.qml",
        "icon": "info",
        "label": "prefs.bar.style.ribbon",
        "desc": "prefs.bar.style.ribbon.desc",
        "edges": ["bottom", "top"],
        "groups": ["start", "center", "end"],
        "flat": true,
        "size": 30,
        "containable": true,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "rail",
        "file": "styles/RailPanel.qml",
        "icon": "sidebarSimple",
        "label": "prefs.bar.style.rail",
        "desc": "prefs.bar.style.rail.desc",
        "edges": ["left", "right"],
        "groups": ["start", "center", "end", "drawer"],
        "flat": true,
        "size": 36,
        "containable": true,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "corners",
        "file": "styles/CornersPanel.qml",
        "icon": "frameCorners",
        "label": "prefs.bar.style.corners",
        "desc": "prefs.bar.style.corners.desc",
        "edges": ALL_EDGES,
        "groups": ["start", "end", "drawer", "gapStart", "gapEnd"],
        "flat": true,
        "size": 30,
        "containable": false,
        "activity": "tab",
        "floating": false
    },
    {
        "id": "dock",
        "file": "styles/DockPanel.qml",
        "icon": "dock",
        "label": "prefs.bar.style.dock",
        "desc": "prefs.bar.style.dock.desc",
        "edges": ["bottom", "left", "right", "top"],
        "groups": ["start", "center", "end"],
        "flat": true,
        "size": 52,
        "containable": false,
        "activity": "pill",
        "floating": true
    },
    // bar.style looks (spec Addendum 2); "classic" is the full-width strip
    {
        "id": "floating",
        "file": "styles/FloatingPanel.qml",
        "icon": "appWindow",
        "label": "prefs.bar.style.floating",
        "desc": "prefs.bar.style.floating.desc",
        "edges": ALL_EDGES,
        "groups": ["start", "center", "end", "drawer", "gapStart", "gapEnd"],
        "flat": false,
        "size": 0,
        "containable": false,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "pills",
        "file": "styles/PillsPanel.qml",
        "icon": "columns",
        "label": "prefs.bar.style.pills",
        "desc": "prefs.bar.style.pills.desc",
        "edges": ALL_EDGES,
        "groups": ["start", "center", "end", "drawer"],
        "flat": false,
        "size": 0,
        "containable": false,
        "activity": "pill",
        "floating": false
    },
    {
        "id": "dock-like",
        "file": "styles/DockLikePanel.qml",
        "icon": "stack",
        "label": "prefs.bar.style.docklike",
        "desc": "prefs.bar.style.docklike.desc",
        "edges": ALL_EDGES,
        "groups": ["start", "center", "end"],
        "flat": false,
        "size": 0,
        "containable": false,
        "activity": "pill",
        "floating": true
    },
    // No bar at all: the panel is never shown and reserves nothing
    {
        "id": "none",
        "file": "",
        "icon": "minus",
        "label": "prefs.bar.style.none",
        "desc": "prefs.bar.style.none.desc",
        "edges": ALL_EDGES,
        "groups": [],
        "flat": false,
        "size": 0,
        "containable": false,
        "activity": "pill",
        "floating": false,
        "hidden": true
    }
];

// The looks offered as `bar.layout.style` cards, in order (spec: full,
// floating, islands, dock-like, none; "classic" = full, "islands" = edge
// tabs, "pills" = groups as separate floating pills).
var BAR_STYLES = ["classic", "floating", "islands", "pills", "dock-like", "none"];

var _byId = {};
for (var _i = 0; _i < STYLES.length; _i++)
    _byId[STYLES[_i].id] = STYLES[_i];

function ids() {
    return STYLES.map(function (s) {
        return s.id;
    });
}

function has(id) {
    return _byId[id] !== undefined;
}

// Registry entry; unknown ids resolve to "classic".
function get(id) {
    return _byId[id] || _byId["classic"];
}

function barStyles() {
    return BAR_STYLES.map(function (id) {
        return _byId[id];
    });
}

// A style that draws no bar ("none"): the panel is disabled.
function isHidden(id) {
    return _byId[id] !== undefined && _byId[id].hidden === true;
}

function supportsEdge(id, edge) {
    return get(id).edges.indexOf(edge) !== -1;
}

function hasGroup(id, group) {
    return get(id).groups.indexOf(group) !== -1;
}
