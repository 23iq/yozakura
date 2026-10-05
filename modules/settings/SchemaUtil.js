.pragma library

// Pure helpers for the schema-driven settings (modules/settings/schema).
// No QML types here: unit tested with node (tests/settings-schema.test.cjs)
// and reused by the audit (tools/audit/checks/settings_schema.py).

// Entry types the generic renderer knows (SettingRow.qml). `custom` loads a
// rich editor from modules/settings/editors/<component>.qml. `color-role`
// edits a color spec (palette role + alpha) or, with `gradient: true`, a
// list of them (gradient stops).
//   list        array editor: `fields` [{key, type, label, ...}] for objects,
//               or `itemType` ("text" | "path") for a list of strings
//   path        file/folder path with a chooser (`pathKind` "file" | "dir")
//   screens     multi-select of monitors by name ([] = every screen)
//   multiselect multi-select of `options` (array of values)
var TYPES = ["toggle", "selector", "slider", "number", "text", "font", "color-role", "custom", "list", "path", "screens", "multiselect"];

// Field types a `list` entry's items may use (controls/ListControl.qml).
var LIST_FIELD_TYPES = ["text", "number", "selector", "path", "toggle"];

// Text value check for `text` entries / list fields with a `pattern`.
function matchesPattern(entry, text) {
    if (!entry || !entry.pattern)
        return true;
    try {
        return new RegExp(entry.pattern).test(String(text));
    } catch (e) {
        return true;
    }
}

// A new list item from `newItem` (or empty values per field type).
function newListItem(entry) {
    if (entry.newItem !== undefined)
        return plain(entry.newItem);
    if (!entry.fields)
        return "";
    var item = {};
    entry.fields.forEach(function (f) {
        if (f.type === "number")
            item[f.key] = f.min !== undefined ? f.min : 0;
        else if (f.type === "toggle")
            item[f.key] = false;
        else if (f.type === "selector")
            item[f.key] = f.options && f.options.length ? f.options[0].value : "";
        else
            item[f.key] = "";
    });
    return item;
}

// Pure list edits (return a new array).
function listInsert(list, item, at) {
    var out = plain(list || []) || [];
    var i = at === undefined || at < 0 || at > out.length ? out.length : at;
    out.splice(i, 0, plain(item));
    return out;
}

function listRemove(list, index) {
    var out = plain(list || []) || [];
    if (index >= 0 && index < out.length)
        out.splice(index, 1);
    return out;
}

function listMove(list, from, to) {
    var out = plain(list || []) || [];
    if (from < 0 || from >= out.length || to < 0 || to >= out.length || from === to)
        return out;
    var item = out.splice(from, 1)[0];
    out.splice(to, 0, item);
    return out;
}

function listSet(list, index, field, value) {
    var out = plain(list || []) || [];
    if (index < 0 || index >= out.length)
        return out;
    if (field === undefined || field === null || field === "")
        out[index] = plain(value);
    else {
        var item = out[index] && typeof out[index] === "object" ? out[index] : {};
        item[field] = plain(value);
        out[index] = item;
    }
    return out;
}

// Multi-select toggle keeping the order of `options` (or insertion order).
function toggleValue(list, value, options) {
    var cur = plain(list || []) || [];
    var has = cur.some(function (v) {
        return equal(v, value);
    });
    var next = has ? cur.filter(function (v) {
        return !equal(v, value);
    }) : cur.concat([value]);
    if (options && options.length) {
        var order = options.map(function (o) {
            return o.value;
        });
        next.sort(function (a, b) {
            return order.indexOf(a) - order.indexOf(b);
        });
    }
    return next;
}

// Value stores. "config" keys are `<domain>.<prop>[.<sub>...]` on the Config
// singleton; "wallpaper" keys live in ~/.cache/yozakura/wallpapers.json and are
// written through the wallpaper manager.
var WALLPAPER_PREFIX = "wallpaper.";

function storeOf(key) {
    return key.indexOf(WALLPAPER_PREFIX) === 0 ? "wallpaper" : "config";
}

function splitKey(key) {
    var parts = String(key).split(".");
    return {
        "domain": parts[0],
        "prop": parts[1],
        "path": parts.slice(1)
    };
}

// JsonAdapter hands lists to JS as list wrappers; normalize to plain JSON.
function plain(value) {
    if (value === undefined || value === null)
        return value;
    if (typeof value !== "object")
        return value;
    try {
        return JSON.parse(JSON.stringify(value));
    } catch (e) {
        return value;
    }
}

function getPath(obj, path) {
    var cur = obj;
    for (var i = 0; i < path.length; i++) {
        if (cur === undefined || cur === null)
            return undefined;
        cur = cur[path[i]];
    }
    return cur;
}

// Returns a deep copy of `obj` with `path` set to `value` (used for nested
// keys inside `property var` objects such as bar.layout.style).
function withPath(obj, path, value) {
    if (path.length === 0)
        return plain(value);
    var copy = plain(obj);
    if (copy === undefined || copy === null || typeof copy !== "object")
        copy = {};
    var cur = copy;
    for (var i = 0; i < path.length - 1; i++) {
        if (cur[path[i]] === undefined || cur[path[i]] === null || typeof cur[path[i]] !== "object")
            cur[path[i]] = {};
        cur = cur[path[i]];
    }
    cur[path[path.length - 1]] = plain(value);
    return copy;
}

function equal(a, b) {
    if (a === b)
        return true;
    if (typeof a === "number" && typeof b === "number")
        return Math.abs(a - b) < 1e-9;
    return JSON.stringify(plain(a)) === JSON.stringify(plain(b));
}

function entryId(entry) {
    return entry.id || entry.key || "";
}

// Every key an entry reads and resets (composite editors list `keys`).
function entryKeys(entry) {
    if (entry.keys && entry.keys.length)
        return entry.keys.slice();
    return entry.key ? [entry.key] : [];
}

function isResettable(entry) {
    return entry.resettable !== false && entryKeys(entry).length > 0;
}

// Declarative conditions, so the audit can check the keys they read:
//   {key, equals} | {key, notEquals} | {key, in: [...]} | {key, truthy: bool}
//   {key, empty: bool} (missing / empty list / empty object)
//   {all: [cond...]} | {any: [cond...]} | {not: cond}
function evalCondition(cond, get) {
    if (!cond)
        return true;
    if (cond.all)
        return cond.all.every(function (c) {
            return evalCondition(c, get);
        });
    if (cond.any)
        return cond.any.some(function (c) {
            return evalCondition(c, get);
        });
    if (cond.not)
        return !evalCondition(cond.not, get);
    var v = get(cond.key);
    if (cond.hasOwnProperty("equals"))
        return equal(v, cond.equals);
    if (cond.hasOwnProperty("notEquals"))
        return !equal(v, cond.notEquals);
    if (cond["in"])
        return cond["in"].some(function (x) {
            return equal(v, x);
        });
    if (cond.hasOwnProperty("truthy"))
        return !!v === !!cond.truthy;
    if (cond.hasOwnProperty("empty"))
        return isEmpty(v) === !!cond.empty;
    return !!v;
}

function isEmpty(v) {
    if (v === undefined || v === null || v === "")
        return true;
    if (typeof v === "object" && typeof v.length === "number")
        return v.length === 0;
    if (typeof v === "object")
        return Object.keys(v).length === 0;
    return false;
}

function conditionKeys(cond) {
    if (!cond)
        return [];
    var out = [];
    ["all", "any"].forEach(function (k) {
        (cond[k] || []).forEach(function (c) {
            out = out.concat(conditionKeys(c));
        });
    });
    if (cond.not)
        out = out.concat(conditionKeys(cond.not));
    if (cond.key)
        out.push(cond.key);
    return out;
}

// [{entry, section, category}] in render order.
function flatten(categories) {
    var out = [];
    (categories || []).forEach(function (cat) {
        (cat.sections || []).forEach(function (sec) {
            (sec.entries || []).forEach(function (entry) {
                out.push({
                    "entry": entry,
                    "section": sec,
                    "category": cat
                });
            });
        });
    });
    return out;
}

// Search index generated from the schema. `tr` translates an i18n key.
// Legacy (not yet migrated) categories contribute their `topics`.
function buildSearchIndex(categories, tr) {
    var t = tr || function (k) {
        return k;
    };
    var out = [];
    (categories || []).forEach(function (cat) {
        var catTitle = t(cat.title);
        out.push({
            "categoryId": cat.id,
            "sectionId": "",
            "entryId": "",
            "label": catTitle,
            "context": "",
            "icon": cat.icon,
            "haystack": [catTitle, cat.keywords || "", cat.description ? t(cat.description) : ""].join(" ").toLowerCase()
        });
        (cat.sections || []).forEach(function (sec) {
            var secTitle = sec.title ? t(sec.title) : "";
            (sec.entries || []).forEach(function (entry) {
                if (!entry.label)
                    return;
                var label = t(entry.label);
                out.push({
                    "categoryId": cat.id,
                    "sectionId": sec.id,
                    "entryId": entryId(entry),
                    "label": label,
                    "context": secTitle ? catTitle + " › " + secTitle : catTitle,
                    "icon": cat.icon,
                    "haystack": [label, entry.keywords || "", entry.description ? t(entry.description) : "", entry.key || "", secTitle].join(" ").toLowerCase()
                });
            });
        });
        (cat.topics || []).forEach(function (topic) {
            var label = t(topic.label);
            out.push({
                "categoryId": cat.id,
                "sectionId": topic.section || "",
                "entryId": "",
                "label": label,
                "context": catTitle,
                "icon": cat.icon,
                "haystack": [label, topic.keywords || ""].join(" ").toLowerCase()
            });
        });
    });
    return out;
}

// Higher is better, -1 = no match. Substring hits beat fuzzy subsequences;
// matches at word starts and in the label beat keyword-only matches.
function score(query, item) {
    var q = String(query || "").trim().toLowerCase();
    if (!q)
        return 0;
    var label = item.label.toLowerCase();
    var words = q.split(/\s+/);
    var total = 0;
    for (var w = 0; w < words.length; w++) {
        var word = words[w];
        var s = -1;
        var li = label.indexOf(word);
        if (li === 0)
            s = 120;
        else if (li > 0)
            s = (/[\s\-_›]/.test(label[li - 1]) ? 100 : 80);
        else if (item.haystack.indexOf(word) !== -1)
            s = 50;
        else
            s = fuzzy(word, label);
        if (s < 0)
            return -1;
        total += s;
    }
    return total - label.length * 0.1 + (item.entryId ? 0 : 5);
}

function fuzzy(q, target) {
    var qi = 0, run = 0, best = 0, s = 0;
    for (var i = 0; i < target.length && qi < q.length; i++) {
        if (target[i] === q[qi]) {
            qi++;
            run++;
            best = Math.max(best, run);
            if (i === 0 || " -_".indexOf(target[i - 1]) !== -1)
                s += 6;
        } else {
            run = 0;
        }
    }
    return qi === q.length && q.length >= 2 ? Math.min(40, s + best * 4) : -1;
}

function search(index, query, limit) {
    var out = [];
    for (var i = 0; i < index.length; i++) {
        var s = score(query, index[i]);
        if (s >= 0)
            out.push({
                "item": index[i],
                "score": s
            });
    }
    out.sort(function (a, b) {
        return b.score - a.score;
    });
    return out.slice(0, limit || 40).map(function (r) {
        return r.item;
    });
}

// Problems in one category (used by the audit and the node tests; the shell
// never calls it). `defaults(key)` returns undefined for unknown keys and
// `tr(key)` returns null for a missing translation.
function validateCategory(cat, defaults, tr, registry) {
    var problems = [];
    function bad(msg) {
        problems.push(cat.id + ": " + msg);
    }
    if (!cat.id || !cat.title || !cat.icon)
        bad("category needs id, title and icon");
    [cat.title, cat.description].forEach(function (k) {
        if (k && tr(k) === null)
            bad("missing translation '" + k + "'");
    });
    (cat.topics || []).forEach(function (topic) {
        if (tr(topic.label) === null)
            bad("missing translation '" + topic.label + "'");
    });
    var seen = {};
    (cat.sections || []).forEach(function (sec) {
        if (!sec.id)
            bad("section without id");
        if (sec.title && tr(sec.title) === null)
            bad("missing translation '" + sec.title + "'");
        (sec.entries || []).forEach(function (e) {
            var id = entryId(e);
            var where = id || "(entry without id)";
            if (!id)
                bad("entry needs a key or an id");
            if (seen[id])
                bad("duplicate entry id '" + id + "'");
            seen[id] = true;
            if (TYPES.indexOf(e.type) === -1)
                bad(where + ": unknown type '" + e.type + "'");
            if (e.type === "custom" && !e.component)
                bad(where + ": custom entry needs a component");
            if (registry && e.type === "custom" && e.component && !registry.EDITORS[e.component])
                bad(where + ": editor '" + e.component + "' is not in Registry.js");
            if (registry && e.preview && !registry.PREVIEWS[e.preview])
                bad(where + ": preview '" + e.preview + "' is not in Registry.js");
            if (e.type !== "custom" && !e.key)
                bad(where + ": typed entry needs a key");
            [e.label, e.description].forEach(function (k) {
                if (k && tr(k) === null)
                    bad(where + ": missing translation '" + k + "'");
            });
            if (!e.label && e.type !== "custom")
                bad(where + ": needs a label");
            entryKeys(e).concat(conditionKeys(e.visibleWhen), conditionKeys(e.enabledWhen)).forEach(function (k) {
                if (defaults(k) === undefined)
                    bad(where + ": key '" + k + "' has no default");
            });
            var def = e.key ? defaults(e.key) : undefined;
            if (e.type === "color-role" && def !== undefined && (e.gradient ? !Array.isArray(def) : typeof def !== "string"))
                bad(where + ": color-role default must be " + (e.gradient ? "a list of color specs" : "a color spec string"));
            if (e.type === "toggle" && def !== undefined && typeof def !== "boolean")
                bad(where + ": toggle default is not a boolean");
            if (e.type === "selector") {
                if (!e.options || e.options.length < 2)
                    bad(where + ": selector needs at least two options");
                else {
                    e.options.forEach(function (o) {
                        if (o.label && tr(o.label) === null)
                            bad(where + ": missing translation '" + o.label + "'");
                    });
                    if (def !== undefined && !e.options.some(function (o) {
                        return equal(o.value, def);
                    }))
                        bad(where + ": default '" + def + "' is not an option");
                }
            }
            if (e.type === "list") {
                if (def !== undefined && !Array.isArray(def))
                    bad(where + ": list default is not an array");
                if (!e.fields && !e.itemType)
                    bad(where + ": list needs `fields` or `itemType`");
                (e.fields || []).forEach(function (f) {
                    if (!f.key || LIST_FIELD_TYPES.indexOf(f.type) === -1)
                        bad(where + ": list field needs a key and a type in " + LIST_FIELD_TYPES.join("/"));
                    [f.label, f.placeholder].forEach(function (k) {
                        if (k && tr(k) === null)
                            bad(where + ": missing translation '" + k + "'");
                    });
                    if (f.type === "selector") {
                        if (!f.options || f.options.length < 2)
                            bad(where + ": list field '" + f.key + "' needs at least two options");
                        (f.options || []).forEach(function (o) {
                            if (o.label && tr(o.label) === null)
                                bad(where + ": missing translation '" + o.label + "'");
                        });
                    }
                    if (f.type === "number" && (typeof f.min !== "number" || typeof f.max !== "number" || f.min >= f.max))
                        bad(where + ": list field '" + f.key + "' needs numeric min < max");
                });
                [e.addLabel, e.itemLabel, e.emptyLabel].forEach(function (k) {
                    if (k && tr(k) === null)
                        bad(where + ": missing translation '" + k + "'");
                });
            }
            if ((e.type === "screens" || e.type === "multiselect") && def !== undefined && !Array.isArray(def))
                bad(where + ": " + e.type + " default is not an array");
            if (e.type === "multiselect") {
                if (!e.options || e.options.length < 2)
                    bad(where + ": multiselect needs at least two options");
                (e.options || []).forEach(function (o) {
                    if (o.label && tr(o.label) === null)
                        bad(where + ": missing translation '" + o.label + "'");
                });
                (def || []).forEach(function (v) {
                    if (!(e.options || []).some(function (o) {
                        return equal(o.value, v);
                    }))
                        bad(where + ": default item '" + v + "' is not an option");
                });
            }
            if ((e.type === "path" || e.type === "text") && def !== undefined && typeof def !== "string")
                bad(where + ": " + e.type + " default is not a string");
            if (e.pattern !== undefined) {
                try {
                    new RegExp(e.pattern);
                    if (typeof def === "string" && !new RegExp(e.pattern).test(def))
                        bad(where + ": default '" + def + "' does not match pattern");
                } catch (err) {
                    bad(where + ": invalid pattern");
                }
            }
            if (e.placeholder && tr(e.placeholder) === null)
                bad(where + ": missing translation '" + e.placeholder + "'");
            if (e.type === "slider" || e.type === "number") {
                if (typeof e.min !== "number" || typeof e.max !== "number" || e.min >= e.max)
                    bad(where + ": needs numeric min < max");
                else if (typeof def === "number" && (def < e.min || def > e.max) && !(e.specialValues || []).some(function (s) {
                    return s.value === def;
                }))
                    bad(where + ": default " + def + " outside [" + e.min + ", " + e.max + "]");
                if (e.step !== undefined && !(e.step > 0))
                    bad(where + ": step must be > 0");
            }
        });
    });
    return problems;
}
