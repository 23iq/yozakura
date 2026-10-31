.pragma library
.import "SchemaUtil.js" as SchemaUtil
.import "ResetModel.js" as ResetModel
.import "presets/PresetStatusModel.js" as PresetStatusModel

// The "Changes" page (changes/ChangesPage.qml): every setting that differs
// from its default, or from the active preset, grouped by settings page.
// Pure, node-tested: tests/settings-changes.test.cjs.
//
// Group: {categoryId, title, icon, rows: [row]}, in sidebar page order.
// Row:   {id, categoryId, sectionId, entryId, label, now, was, entry?, key?,
//         target?}  label is display text; now / was are short value texts
//         ("" for a composite editor); `target` = the preset's raw value.

// A value as the row shows it: an option's label, on/off, a short JSON.
function describe(entry, value, tr) {
    var t = tr || function (k) {
        return k;
    };
    var opts = entry && entry.options;
    for (var i = 0; opts && i < opts.length; i++) {
        if (SchemaUtil.equal(opts[i].value, value))
            return t(opts[i].label);
    }
    if (entry && entry.invert && typeof value === "boolean")
        value = !value;
    var unit = entry && entry.unit ? " " + entry.unit : "";
    if (typeof value === "number")
        return (Math.round(value * 100) / 100) + unit;
    // a custom editor keeps its options to itself: "islands" -> "Islands"
    if (typeof value === "string" && /^[a-z][a-zA-Z0-9_-]*$/.test(value))
        return value.charAt(0).toUpperCase() + value.slice(1);
    return PresetStatusModel.valueText(value, t("common.on"), t("common.off"));
}

function group(out, cat, row, tr) {
    var g = null;
    for (var i = 0; i < out.length; i++) {
        if (out[i].categoryId === row.categoryId)
            g = out[i];
    }
    if (!g) {
        g = {
            "categoryId": row.categoryId,
            "title": cat ? tr(cat.title) : tr("prefs.changes.other"),
            "icon": cat ? cat.icon : "gear",
            "rows": []
        };
        out.push(g);
    }
    g.rows.push(row);
}

function count(groups) {
    return (groups || []).reduce(function (n, g) {
        return n + g.rows.length;
    }, 0);
}

// Since defaults: the entries a page reset would touch (ResetModel: shown,
// on the running compositor) whose value differs from the default.
// ctx = {compositor, get}; isModified(entry); def(key) = the default.
function fromDefaults(categories, ctx, isModified, def, tr) {
    var t = tr || function (k) {
        return k;
    };
    var out = [];
    (categories || []).forEach(function (cat) {
        if (!cat.sections)
            return;
        ResetModel.activeItems(cat, ctx).forEach(function (it) {
            if (!isModified(it.entry))
                return;
            var single = !!it.entry.key && !(it.entry.keys && it.entry.keys.length > 1);
            group(out, cat, {
                "id": cat.id + "/" + SchemaUtil.entryId(it.entry),
                "categoryId": cat.id,
                "sectionId": it.section.id || "",
                "entryId": SchemaUtil.entryId(it.entry),
                "label": t(it.entry.label || ""),
                "now": single ? describe(it.entry, ctx.get(it.entry.key), t) : "",
                "was": single ? describe(it.entry, def(it.entry.key), t) : "",
                "entry": it.entry
            }, t);
        });
    });
    return out;
}

// Since the active preset: the backend's preset.status changes
// ([{key, a: live, b: preset}]), each on the page of its settings entry
// (`index`: the sidebar search index), the rest under "Other".
function fromPreset(changes, index, categories, tr) {
    var t = tr || function (k) {
        return k;
    };
    var byId = {};
    (categories || []).forEach(function (c) {
        byId[c.id] = c;
    });
    var out = [];
    (changes || []).forEach(function (c) {
        var e = PresetStatusModel.entryFor(index, c.key);
        var full = e ? flatEntry(byId[e.categoryId], e.entryId) : null;
        group(out, e ? byId[e.categoryId] : null, {
            "id": "preset/" + c.key,
            "categoryId": e ? e.categoryId : "",
            "sectionId": e ? e.sectionId : "",
            "entryId": e ? e.entryId : "",
            "label": e ? e.label : PresetStatusModel.humanKey(c.key),
            "now": describe(full && full.key === c.key ? full : null, c.a, t),
            "was": describe(full && full.key === c.key ? full : null, c.b, t),
            "key": c.key,
            "target": c.b
        }, t);
    });
    // pages in sidebar order, "Other" last
    var order = (categories || []).map(function (c) {
        return c.id;
    });
    out.sort(function (a, b) {
        var ia = order.indexOf(a.categoryId), ib = order.indexOf(b.categoryId);
        return (ia < 0 ? 1e6 : ia) - (ib < 0 ? 1e6 : ib);
    });
    return out;
}

function flatEntry(cat, entryId) {
    var found = null;
    SchemaUtil.flatten(cat ? [cat] : []).forEach(function (it) {
        if (SchemaUtil.entryId(it.entry) === entryId)
            found = it.entry;
    });
    return found;
}
