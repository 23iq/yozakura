.pragma library
.import "SchemaUtil.js" as SchemaUtil
.import "CompositorGate.js" as CompositorGate

// Which entries "Reset page", the modified counters and the Changes page may
// touch. Pure (node-tested): the store passes the live context.
//
// Rules: an entry that is hidden (visibleWhen false) or tied to another
// compositor than the running one is skipped, and so is every entry that
// only holds `compositor.*` keys (the Hyprland appearance domain) unless
// Hyprland is the running compositor: schema defaults are never applied to a
// compositor that is not active. Reset page and the counters also skip what
// is not a row of the window (SchemaUtil.inWindow): a page reset never
// touches settings the user cannot see on the page. The Changes page lists
// those too (changedItems), without a jump to a row that does not exist.

var HYPRLAND_DOMAIN = "compositor";

function keysAreHyprlandOnly(entry) {
    var keys = SchemaUtil.entryKeys(entry);
    if (keys.length === 0)
        return false;
    return keys.every(function (k) {
        return SchemaUtil.splitKey(k).domain === HYPRLAND_DOMAIN;
    });
}

// Applies on the running compositor and is not hidden (a window row or not).
// ctx = {compositor: string, get: function(key)}
function entryApplies(entry, section, ctx) {
    var comp = entry.compositor || (section && section.compositor) || "";
    if (comp && !CompositorGate.allows(comp, ctx.compositor))
        return false;
    if (!comp && keysAreHyprlandOnly(entry) && ctx.compositor !== "hyprland")
        return false;
    return SchemaUtil.evalCondition(entry.visibleWhen, ctx.get);
}

function entryActive(entry, section, ctx) {
    return SchemaUtil.inWindow(entry, section) && entryApplies(entry, section, ctx);
}

// [{entry, section, category}] of a category that a reset may touch.
function activeItems(category, ctx) {
    return SchemaUtil.flatten([category]).filter(function (it) {
        return entryActive(it.entry, it.section, ctx);
    });
}

// [{entry, section, category, inWindow}] of a category the Changes page may
// list: its window rows and its out-of-window entries. An out-of-window
// entry whose every key a window row of the category already holds is left
// to that row (listed once).
function changedItems(category, ctx) {
    var all = SchemaUtil.flatten([category]).filter(function (it) {
        return entryApplies(it.entry, it.section, ctx);
    });
    var covered = {};
    all.forEach(function (it) {
        it.inWindow = SchemaUtil.inWindow(it.entry, it.section);
        if (it.inWindow)
            SchemaUtil.entryKeys(it.entry).forEach(function (k) {
                covered[k] = true;
            });
    });
    return all.filter(function (it) {
        return it.inWindow || !SchemaUtil.entryKeys(it.entry).every(function (k) {
            return covered[k];
        });
    });
}
