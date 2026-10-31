.pragma library

// Pure helpers of the active preset status (PresetStatusFooter, the changes
// sheet and the preset switcher row). status: backend `preset.status`
// ({active, official, owned, changed, changes: [{key, a: live, b: preset}],
// session}). Node-tested: tests/preset-status-model.test.cjs.

// What the primary button does: "save" (a user preset), "saveAs" (a
// built-in one) or "" (nothing to save, or a try/edit/preview owns the
// live config).
function primaryAction(status) {
    if (!status || !status.active || !(status.changed > 0) || status.session)
        return "";
    return status.owned ? "save" : "saveAs";
}

// The search index entry (SchemaUtil.buildSearchIndex) of a changed key:
// the entry of that key, else of its closest enclosing key; null if none.
function entryFor(index, key) {
    var best = null;
    for (var i = 0; i < (index || []).length; i++) {
        var e = index[i];
        if (!e.key || !e.entryId)
            continue;
        if (key === e.key || key.indexOf(e.key + ".") === 0) {
            if (!best || e.key.length > best.key.length)
                best = e;
        }
    }
    return best;
}

// A readable title for a changed key without a settings entry:
// "theme.blurRadius" -> "Theme · Blur radius".
function humanKey(key) {
    return String(key || "").split(".").map(function (part) {
        var words = part.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
        return words.charAt(0).toUpperCase() + words.slice(1);
    }).join(" · ");
}

// A short rendering of a setting value; on/off for booleans.
function valueText(v, on, off) {
    if (v === undefined || v === null)
        return "—";
    if (typeof v === "boolean")
        return v ? on : off;
    if (typeof v === "string")
        return v === "" ? "\"\"" : v;
    var s = JSON.stringify(v);
    return s.length > 40 ? s.slice(0, 37) + "…" : s;
}

// The rows of the changes sheet: [{key, title, context, now, preset, entry}].
function rows(status, index, on, off) {
    var out = [];
    var changes = (status && status.changes) || [];
    for (var i = 0; i < changes.length; i++) {
        var c = changes[i];
        var e = entryFor(index, c.key);
        out.push({
            "key": c.key,
            "title": e ? e.label : humanKey(c.key),
            "context": e ? (e.context || "") : "",
            "now": valueText(c.a, on, off),
            "preset": valueText(c.b, on, off),
            "entry": e
        });
    }
    return out;
}
