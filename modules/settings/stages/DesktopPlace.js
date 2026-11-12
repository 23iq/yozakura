.pragma library
.import "../../desktop/widgets/WidgetRegistry.js" as Registry
.import "../../desktop/widgets/WidgetGeometry.js" as Geometry

// Pure helpers of the Widgets page (node-tested in
// tests/settings-desktop-place.test.cjs): a widget type turned on or off
// from its chip, and where the depth clock sits on the miniature.

// Widgets of `type` on the list (desktop.widgets, normalized).
function countOf(list, type) {
    return (list || []).filter(function (w) {
        return w && w.type === type;
    }).length;
}

// The list with `type` turned on (one widget added in the first free spot
// of the first screen, clear of the others and of `avoid` rects, on the
// widget grid) or off (every widget of that type removed).
//   list     desktop.widgets (plain)
//   screen   {name, w, h} of the first screen
//   grid     desktop.widgetGrid (px, 0 = free placement)
//   avoid    [{x, y, w, h}] px (the depth clock, the bars)
function toggled(list, type, screen, grid, avoid) {
    var all = Registry.normalizeList(list || []);
    if (!Registry.has(type))
        return all;
    if (countOf(all, type) > 0)
        return all.filter(function (w) {
            return w.type !== type;
        });
    var sw = screen.w, sh = screen.h;
    var size = Registry.sizeFraction(type, sw, sh);
    var px = {
        "w": Math.round(size.w * sw),
        "h": Math.round(size.h * sh)
    };
    var taken = Geometry.forScreen(all, screen.name || "", [screen.name || ""]).map(function (w) {
        return Geometry.toPixels(w, sw, sh);
    }).concat(avoid || []);
    var g = grid > 0 ? grid : 16;
    var spot = Geometry.freeSpot(px, {
        "x": 0,
        "y": 0,
        "w": sw,
        "h": sh
    }, taken, grid, g);
    var rel = Geometry.toRelative(spot, sw, sh);
    return all.concat([{
            "id": Registry.newId(type),
            "type": type,
            "monitor": screen.name || "",
            "x": rel.x,
            "y": rel.y,
            "w": rel.w,
            "h": rel.h,
            "options": Registry.defaultOptions(type)
        }]);
}

// The depth clock's side for its position setting ("auto" sits right).
function clockSide(position) {
    return position === "left" ? "left" : "right";
}
