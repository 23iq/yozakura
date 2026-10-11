.pragma library
.import "SchemaUtil.js" as SchemaUtil

// Which entries "Reset page" / "Reset section" and the modified counters may
// touch. Pure (node-tested): the store passes the live context.
//
// Rules: an entry that is hidden (visibleWhen false) or tied to another
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
    var comp = entry.compositor || (section && section.compositor) || "";
    if (comp && ctx.compositor !== comp)
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

// Does resetting `items` touch values that no Apply / Discard covers?
// `isStaged(domain)` tells the staged domains.
function unstagedKeys(items, isModified, isStaged) {
    var out = [];
    items.forEach(function (it) {
        if (!isModified(it.entry))
            return;
        SchemaUtil.entryKeys(it.entry).forEach(function (k) {
            var d = SchemaUtil.splitKey(k).domain;
            if (d !== "wallpaper" && !isStaged(d) && out.indexOf(k) === -1)
                out.push(k);
        });
    });
    return out;
}
