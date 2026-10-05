.pragma library
.import "../bar/BarLayout.js" as BarLayout
.import "../bar/BarModuleRegistry.js" as Registry

// Presentation of the bar modules (modules/bar/BarModuleRegistry.js): icon
// (Icons name) and label key, plus the legacy bar.layout edit helpers.

var INFO = {};
Registry.MODULES.forEach(function (m) {
    INFO[m.id] = {
        "icon": m.icon,
        "label": m.label
    };
});

var GROUPS = ["left", "right", "drawer"];

function ids() {
    return BarLayout.MODULE_IDS.slice();
}

function info(id) {
    return INFO[id] || {
        "icon": "puzzlePiece",
        "label": id
    };
}

// The bar layout as {style, left, right, drawer} with unknown ids dropped.
function layoutOf(raw) {
    var n = BarLayout.normalize(raw, BarLayout.DEFAULT_LAYOUT);
    return {
        "style": n.style,
        "left": n.left,
        "right": n.right,
        "drawer": n.drawer
    };
}

// Modules not placed in any group.
function unused(layout) {
    var used = layout.left.concat(layout.right, layout.drawer);
    return ids().filter(function (id) {
        return used.indexOf(id) === -1;
    });
}

// Returns a new layout with `id` moved to `group` at `index` (clamped).
// group "available" removes it from the bar.
function move(layout, id, group, index) {
    var out = {
        "style": layout.style,
        "left": layout.left.filter(function (x) {
            return x !== id;
        }),
        "right": layout.right.filter(function (x) {
            return x !== id;
        }),
        "drawer": layout.drawer.filter(function (x) {
            return x !== id;
        })
    };
    if (GROUPS.indexOf(group) !== -1) {
        var list = out[group];
        var i = Math.max(0, Math.min(index === undefined || index < 0 ? list.length : index, list.length));
        list.splice(i, 0, id);
    }
    return out;
}

// Where `id` currently is: {group, index}; group "available" when unused.
function locate(layout, id) {
    for (var g = 0; g < GROUPS.length; g++) {
        var i = layout[GROUPS[g]].indexOf(id);
        if (i !== -1)
            return {
                "group": GROUPS[g],
                "index": i
            };
    }
    return {
        "group": "available",
        "index": unused(layout).indexOf(id)
    };
}
