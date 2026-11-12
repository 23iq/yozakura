.pragma library
.import "SchemaUtil.js" as SchemaUtil
.import "CompositorGate.js" as CompositorGate

// Which entries "Reset page" and the modified counters may touch. Pure (node-tested): the store passes the live context.
//
// Rules: an entry that is not in the window (SchemaUtil.inWindow), hidden (visibleWhen false) or tied to another
// compositor than the running one is skipped, and so is every entry that
// only holds `compositor.*` keys (the Hyprland appearance domain) unless
// Hyprland is the running compositor: schema defaults are never applied to a
// compositor that is not active, and never to settings the user cannot see.

var HYPRLAND_DOMAIN = "compositor";

function keysAreHyprlandOnly(entry) {
    var keys = SchemaUtil.entryKeys(entry);
    if (keys.length === 0)
        return false;
    return keys.every(function (k) {
        return SchemaUtil.splitKey(k).domain === HYPRLAND_DOMAIN;
    });
}

// ctx = {compositor: string, get: function(key)}
function entryActive(entry, section, ctx) {
    if (!SchemaUtil.inWindow(entry, section))
        return false;
    var comp = entry.compositor || (section && section.compositor) || "";
    if (comp && !CompositorGate.allows(comp, ctx.compositor))
        return false;
    if (!comp && keysAreHyprlandOnly(entry) && ctx.compositor !== "hyprland")
        return false;
    return SchemaUtil.evalCondition(entry.visibleWhen, ctx.get);
}

// [{entry, section, category}] of a category that a reset may touch.
function activeItems(category, ctx) {
    return SchemaUtil.flatten([category]).filter(function (it) {
        return entryActive(it.entry, it.section, ctx);
    });
}
