.pragma library
.import "../bar/panels/PanelStyles.js" as PanelStyles
.import "../bar/BarModuleRegistry.js" as Modules

// Geometry of the panels schematic (previews/PanelsSchematic.qml): each
// panel as shapes (bands, tabs, a floating dock) and module icon slots, in
// the coordinates of a W x H screen mockup. Pure, tested in
// tests/panels-model.test.cjs.
//
// sketch(panel, W, H, unit) -> {shapes: [{x, y, w, h, r, kind}],
//                              icons: [{x, y, size, icon}], depth}
// kind: "band" | "tab" | "dock"; depth = space taken from the edge.

function iconOf(id) {
    var m = Modules.get(id);
    return m ? m.icon : "puzzlePiece";
}

// Lay out a run of ids along x starting at `from` (or centered on `center`).
function run(ids, from, cross, slot, size) {
    var out = [];
    for (var i = 0; i < ids.length; i++) {
        out.push({
            "x": from + i * slot + (slot - size) / 2,
            "y": cross - size / 2,
            "size": size,
            "icon": iconOf(ids[i])
        });
    }
    return out;
}

// Map a shape/icon from the "top edge" frame to `edge`.
function place(item, edge, W, H) {
    var o = JSON.parse(JSON.stringify(item));
    var w = o.w !== undefined ? o.w : o.size;
    var h = o.h !== undefined ? o.h : o.size;
    switch (edge) {
    case "bottom":
        o.y = H - o.y - h;
        break;
    case "left":
        o.x = item.y;
        o.y = item.x;
        if (o.w !== undefined) {
            o.w = h;
            o.h = w;
        }
        break;
    case "right":
        o.x = W - item.y - h;
        o.y = item.x;
        if (o.w !== undefined) {
            o.w = h;
            o.h = w;
        }
        break;
    }
    return o;
}

function sketch(panel, W, H, unit) {
    var style = PanelStyles.get(panel.style);
    var vertical = panel.edge === "left" || panel.edge === "right";
    var len = vertical ? H : W;
    var g = panel.groups || {};
    var start = g.start || [];
    var center = g.center || [];
    var end = (g.end || []);
    var slot = unit * (style.flat ? 0.95 : 1.05);
    var size = unit * 0.62;
    var shapes = [];
    var icons = [];
    var depth = 0;

    var thin = {
        "menubar": 0.78,
        "statusline": 0.7,
        "ribbon": 0.9
    }[style.id] || 1;
    var t = Math.round(unit * thin + unit * 0.3);
    var cross;
    // Floating looks sit off the edge by this much
    var lift = Math.round(unit * 0.4);

    if (style.hidden) {
        return {
            "shapes": [],
            "icons": [],
            "depth": 0
        };
    } else if (style.id === "dock" || style.id === "dock-like") {
        var all = start.concat(center, end);
        var gaps = [start, center, end].filter(function (x) {
            return x.length > 0;
        }).length - 1;
        var dslot = style.id === "dock" ? unit * 1.15 : slot;
        var w = all.length * dslot + Math.max(0, gaps) * unit * 0.4 + unit * 0.5;
        var margin = Math.round(unit * 0.35);
        var dt = style.id === "dock" ? Math.round(unit * 1.5) : t;
        var x0 = panel.align === "start" ? unit : (panel.align === "end" ? len - w - unit : (len - w) / 2);
        shapes.push({
            "x": x0,
            "y": margin,
            "w": w,
            "h": dt,
            "r": dt * 0.32,
            "kind": "dock"
        });
        var x = x0 + unit * 0.25;
        [start, center, end].forEach(function (grp) {
            if (grp.length === 0)
                return;
            icons = icons.concat(run(grp, x, margin + dt / 2, dslot, unit * 0.9));
            x += grp.length * dslot + unit * 0.4;
        });
        depth = margin + dt;
    } else if (style.id === "islands" || style.id === "corners" || style.id === "pills") {
        var pills = style.id === "pills";
        var off = pills ? lift : 0;
        cross = off + t / 2;
        var groupsOnTabs = [["start", start], ["end", end.concat([])]];
        if (style.id !== "corners" && center.length > 0)
            groupsOnTabs.push(["center", center]);
        groupsOnTabs.forEach(function (pair) {
            var ids = pair[1];
            if (ids.length === 0)
                return;
            var tw = ids.length * slot + unit * 0.5;
            var tx = pair[0] === "start" ? off : (pair[0] === "end" ? len - tw - off : (len - tw) / 2);
            shapes.push({
                "x": tx,
                "y": off,
                "w": tw,
                "h": t,
                "r": pills ? t / 2 : t * 0.45,
                "kind": pills ? "dock" : "tab"
            });
            icons = icons.concat(run(ids, tx + unit * 0.25, cross, slot, size));
        });
        depth = off + t;
    } else {
        var floating = style.id === "floating";
        var inset = floating ? lift : (style.id === "classic" && panel.margin !== 0 ? Math.round(unit * 0.18) : 0);
        shapes.push({
            "x": inset,
            "y": inset,
            "w": len - 2 * inset,
            "h": t,
            "r": floating ? t / 2 : (inset > 0 ? t * 0.35 : 0),
            "kind": "band"
        });
        cross = inset + t / 2;
        var pad = unit * 0.4 + inset;
        icons = icons.concat(run(start, pad, cross, slot, size));
        icons = icons.concat(run(center, (len - center.length * slot) / 2, cross, slot, size));
        icons = icons.concat(run(end, len - pad - end.length * slot, cross, slot, size));
        depth = inset + t;
    }

    return {
        "shapes": shapes.map(function (s) {
            return place(s, panel.edge, W, H);
        }),
        "icons": icons.map(function (i) {
            return place(i, panel.edge, W, H);
        }),
        "depth": panel.reserve === false || panel.autohide === "always" ? 0 : depth
    };
}
