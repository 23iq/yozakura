.pragma library
.import "SchemaUtil.js" as SchemaUtil
.import "DisabledReason.js" as DisabledReason

// A card of the page row whose rows wait on one switch (a feature that is
// off: the media panel, the depth clock, the fish prompt). Instead of a
// sentence per row ("Needs X on · Turn on") or a card that only says it is
// off, the card shows those rows as they would be, dimmed, and offers ONE
// "Turn on X" for the whole card; picking something in a dimmed row turns
// the switch on too (SettingsSection / SettingRow `preview`).
//
// gate(entries, get, lookup) -> {fix: {key, value, entry, on}, ids: [entry ids]} | null
// `entries`: the card's window entries; `get(key)` reads a value;
// `lookup(key)` the entry that edits a key (DisabledReason). A row waits
// when it is hidden (visibleWhen) or greyed (enabledWhen) and one switch
// fixes it (a row that waits on something else keeps its own way). null
// when no row waits, or the waiting rows need different switches.

function idOf(entry) {
    return entry.id || entry.key;
}

// The one switch that would bring `entry` (null: it is live, or no single
// switch brings it).
function blocker(entry, get, lookup) {
    var visible = SchemaUtil.evalCondition(entry.visibleWhen, get);
    var usable = visible && SchemaUtil.evalCondition(entry.enabledWhen, get);
    if (usable)
        return null;
    var cond = visible ? entry.enabledWhen : entry.visibleWhen;
    var leaf = DisabledReason.failing(cond, get);
    var fix = DisabledReason.fixFor(leaf, lookup, get);
    // the switch itself is never one of its own card's waiting rows
    return fix && fix.key !== entry.key ? fix : {
        "key": ""
    };
}

function gate(entries, get, lookup) {
    var fix = null;
    var ids = [];
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i];
        var b = blocker(e, get, lookup);
        if (!b)
            continue;
        // waits on something no click fixes: it keeps its own way
        if (!b.key)
            continue;
        if (fix && fix.key !== b.key)
            return null;
        fix = b;
        ids.push(idOf(e));
    }
    return fix ? {
        "fix": fix,
        "ids": ids
    } : null;
}
