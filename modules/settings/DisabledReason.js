.pragma library
.import "SchemaUtil.js" as SchemaUtil

// Why a greyed row (enabledWhen false) is greyed, in one line, and the one
// switch that would enable it. Pure: `get(key)` reads a value, `lookup(key)`
// returns the schema entry that edits a key (or null), `tr(k)` translates.
//
// The first condition that fails decides. When it is a single switch
// ({key, equals: bool} | {key, truthy} | {key, notEquals: bool} on a toggle
// entry), the note names that switch ("Needs “Glass effect” on") and offers
// to flip it; otherwise the entry's own `reason` (an i18n key) explains it.

// The first failing leaf of `cond`, or the failing composite itself when
// it cannot be reduced to one leaf (any / not).
function failing(cond, get) {
    if (!cond || SchemaUtil.evalCondition(cond, get))
        return null;
    if (cond.all) {
        for (var i = 0; i < cond.all.length; i++) {
            var f = failing(cond.all[i], get);
            if (f)
                return f;
        }
        return null;
    }
    return cond;
}

// The value a leaf asks a boolean key for (undefined: not a switch leaf).
function wanted(leaf) {
    if (!leaf || !leaf.key)
        return undefined;
    if (leaf.hasOwnProperty("equals"))
        return typeof leaf.equals === "boolean" ? leaf.equals : undefined;
    if (leaf.hasOwnProperty("notEquals"))
        return typeof leaf.notEquals === "boolean" ? !leaf.notEquals : undefined;
    if (leaf.hasOwnProperty("truthy"))
        return !!leaf.truthy;
    if (leaf.hasOwnProperty("in") || leaf.hasOwnProperty("empty") || leaf.hasOwnProperty("some"))
        return undefined;
    return true;
}

// {key, value, entry, on} when the leaf is one toggle the user can flip
// from the note; `on`: the toggle shows "on" after the fix (an inverted
// toggle shows on for false).
function fixFor(leaf, lookup, get) {
    var value = wanted(leaf);
    if (value === undefined || !lookup)
        return null;
    var target = lookup(leaf.key);
    if (!target || target.type !== "toggle")
        return null;
    if (target.enabledWhen && !SchemaUtil.evalCondition(target.enabledWhen, get))
        return null;
    return {
        "key": leaf.key,
        "value": value,
        "entry": target,
        "on": target.invert ? !value : value
    };
}

// {text, fix} for a greyed entry, null when it is not greyed.
function explain(entry, get, lookup, tr) {
    var t = tr || function (k) {
        return k;
    };
    var leaf = failing(entry && entry.enabledWhen, get);
    if (!leaf)
        return null;
    var fix = fixFor(leaf, lookup, get);
    var text;
    if (fix)
        text = t(fix.on ? "prefs.disabled.needs_on" : "prefs.disabled.needs_off").replace("%1", t(fix.entry.label));
    else if (entry.reason)
        text = t(entry.reason);
    else
        text = t("prefs.disabled.generic");
    return {
        "text": text,
        "fix": fix
    };
}

// Leaves of a condition (all / any / not flattened).
function leaves(cond) {
    if (!cond)
        return [];
    var out = [];
    ["all", "any"].forEach(function (k) {
        (cond[k] || []).forEach(function (c) {
            out = out.concat(leaves(c));
        });
    });
    if (cond.not)
        out.push(cond);
    if (cond.key)
        out.push(cond);
    return out;
}

// Does an entry need its own `reason`? True when some way its condition can
// fail is not one switch the note could name (the audit test checks every
// such entry declares one).
function needsReason(entry, lookup) {
    var cond = entry && entry.enabledWhen;
    if (!cond)
        return false;
    if (cond.any || cond.not)
        return true;
    return leaves(cond).some(function (leaf) {
        if (wanted(leaf) === undefined)
            return true;
        var target = lookup ? lookup(leaf.key) : null;
        return !target || target.type !== "toggle";
    });
}

// key -> the first schema entry that edits it, over every category.
function entryIndex(categories) {
    var out = {};
    (categories || []).forEach(function (cat) {
        (cat.sections || []).forEach(function (sec) {
            (sec.entries || []).forEach(function (e) {
                if (e.key && !out[e.key])
                    out[e.key] = e;
            });
        });
    });
    return out;
}
