.pragma library
.import "../../config/KeybindActions.js" as Actions
.import "../../config/CoreBinds.js" as CoreBinds
.import "KeyNames.js" as KeyNames

// binds.json as a flat list of rows for the cheatsheet and the editor:
// grouping, search, conflict detection and the pure edits of the custom
// list. The QML side (KeybindsStore.qml) only reads/writes the adapter.
// Tested in tests/keybinds.test.cjs.
//
// Row: {uid, kind: "core"|"custom"|"special", path (core), index (custom),
//       keys: [{modifiers, key}], actions: [{id, args, layouts}],
//       enabled, name, group} (special: + specialId, role "toggle"|"send")

// Groups in display order. `title`/`desc` are translation keys, `icon` an
// Icons property. Adding a group = one entry (+ translations); actions pick
// theirs with `group` in KeybindActions.js.
var GROUPS = [
    { "id": "windows", "icon": "appWindow", "title": "binds.group.windows", "desc": "binds.group.windows.desc" },
    { "id": "workspaces", "icon": "squaresFour", "title": "binds.group.workspaces", "desc": "binds.group.workspaces.desc" },
    { "id": "shell", "icon": "widgets", "title": "binds.group.shell", "desc": "binds.group.shell.desc" },
    { "id": "ai", "icon": "sparkle", "title": "binds.group.ai", "desc": "binds.group.ai.desc" },
    { "id": "media", "icon": "musicNotes", "title": "binds.group.media", "desc": "binds.group.media.desc" },
    { "id": "screenshots", "icon": "camera", "title": "binds.group.screenshots", "desc": "binds.group.screenshots.desc" },
    { "id": "system", "icon": "lock", "title": "binds.group.system", "desc": "binds.group.system.desc" },
    { "id": "apps", "icon": "terminalWindow", "title": "binds.group.apps", "desc": "binds.group.apps.desc" }
];

var LAYOUTS = ["dwindle", "master", "scrolling"];

function group(id) {
    for (var i = 0; i < GROUPS.length; i++) {
        if (GROUPS[i].id === id)
            return GROUPS[i];
    }
    return GROUPS[GROUPS.length - 1];
}

function plain(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

function keyOf(k) {
    return {
        "modifiers": (k && k.modifiers) ? Array.prototype.slice.call(k.modifiers) : [],
        "key": (k && k.key) ? String(k.key) : ""
    };
}

function actionOf(a) {
    var fixed = Actions.ensureAction(a) || {
        "id": "command.run",
        "args": {}
    };
    return {
        "id": fixed.id,
        "args": plain(fixed.args) || {},
        "layouts": (a && a.layouts) ? Array.prototype.slice.call(a.layouts) : []
    };
}

// Rows from a plain snapshot {root, custom, disabled} of binds.json.
function buildRows(data) {
    var out = [];
    var disabled = (data && data.disabled) || [];
    CoreBinds.BINDS.forEach(function (entry) {
        var bind = CoreBinds.lookup(data && data.root, entry);
        if (!bind)
            return;
        var p = CoreBinds.path(entry);
        var action = actionOf(bind.action || {
            "id": CoreBinds.actionId(entry)
        });
        out.push({
            "uid": "core:" + p,
            "kind": "core",
            "path": p,
            "index": -1,
            "keys": [keyOf(bind)],
            "actions": [action],
            "enabled": disabled.indexOf(p) === -1,
            "name": "",
            "group": Actions.groupOf(action.id)
        });
    });
    var custom = (data && data.custom) || [];
    for (var i = 0; i < custom.length; i++) {
        var c = custom[i] || {};
        var keys = c.keys ? Array.prototype.map.call(c.keys, keyOf) : [keyOf(c)];
        var actions = c.actions ? Array.prototype.map.call(c.actions, actionOf) : [actionOf(c)];
        out.push({
            "uid": "custom:" + i,
            "kind": "custom",
            "path": "",
            "index": i,
            "keys": keys,
            "actions": actions,
            "enabled": c.enabled !== false,
            "name": c.name || "",
            "group": actions.length ? Actions.groupOf(actions[0].id) : "apps"
        });
    }
    // Special workspace binds (kind "special", built by
    // modules/specials/Specials.js bindRows): stored in specials.json.
    var specials = (data && data.specials) || [];
    for (var j = 0; j < specials.length; j++)
        out.push(specials[j]);
    return out;
}

// --- Text ------------------------------------------------------------------

// `tr(key)` translates; a missing key (returned unchanged) falls back to the
// catalog's English label.
function actionLabel(id, tr) {
    var key = Actions.labelKey(id);
    var t = tr ? tr(key) : key;
    if (t && t !== key)
        return t;
    var entry = Actions.getActionById(id);
    return entry ? entry.label : String(id || "");
}

function actionDetail(action) {
    var fields = Actions.getActionFields(action.id);
    var args = action.args || {};
    return fields.map(function (f) {
        return args[f.key];
    }).filter(function (v) {
        return v !== undefined && v !== null && String(v) !== "";
    }).join(" ");
}

// "Switch Workspace · 3"; an app bind is the app's name ("Firefox", see
// withApps), else "Open app · <desktop id>".
function actionText(action, tr) {
    if (action.id === "apps.launch" && action.appName)
        return action.appName;
    var detail = actionDetail(action);
    var label = actionLabel(action.id, tr);
    return detail ? label + " · " + detail : label;
}

// Rows with the installed app's name and icon on every "apps.launch"
// action (display only, never written back). `lookup(desktopId)` returns
// {name, icon} or null (not installed: the id is shown).
function withApps(rows, lookup) {
    return rows.map(function (row) {
        if (!row.actions.some(function (a) {
            return a.id === "apps.launch";
        }))
            return row;
        return Object.assign({}, row, {
            "actions": row.actions.map(function (a) {
                var id = a.id === "apps.launch" ? Actions.appIdOf(a) : "";
                var info = id && lookup ? lookup(id) : null;
                if (!info)
                    return a;
                return Object.assign({}, a, {
                    "appName": info.name || id,
                    "appIcon": info.icon || ""
                });
            })
        });
    });
}

// The first app a row opens ({id, name, icon}), or null.
function appOf(row) {
    for (var i = 0; i < row.actions.length; i++) {
        var a = row.actions[i];
        if (a.id === "apps.launch")
            return {
                "id": Actions.appIdOf(a),
                "name": a.appName || "",
                "icon": a.appIcon || ""
            };
    }
    return null;
}

// Uses something only the editor's "Advanced" part shows: several combos
// or actions, layout limits or a raw dispatcher.
function isAdvanced(row) {
    if (row.kind !== "custom")
        return false;
    return row.keys.length > 1 || row.actions.length > 1 || row.actions.some(function (a) {
        return (a.layouts && a.layouts.length > 0) || a.id === "legacy.dispatcher";
    });
}

function title(row, tr) {
    if (row.name)
        return row.name;
    return row.actions.length ? actionText(row.actions[0], tr) : "";
}

// Second line: what the bind does when the title is a custom description.
function subtitle(row, tr) {
    var parts = row.actions.map(function (a) {
        return actionText(a, tr);
    });
    var text = parts.join(", ");
    return text.toLowerCase() === title(row, tr).toLowerCase() ? "" : text;
}

function searchText(row, tr) {
    var parts = [title(row, tr), subtitle(row, tr), row.path, tr ? tr(group(row.group).title) : row.group];
    row.keys.forEach(function (k) {
        parts.push(KeyNames.comboText(k.modifiers, k.key));
        parts.push((k.modifiers || []).join(" ") + " " + k.key);
    });
    row.actions.forEach(function (a) {
        parts.push(a.id);
        if (a.appName)
            parts.push(a.appName);
        var entry = Actions.getActionById(a.id);
        if (entry)
            parts.push(entry.label);
    });
    return parts.join(" ").toLowerCase();
}

// Every whitespace-separated token of `query` must match.
function filterRows(rows, query, tr) {
    var tokens = String(query || "").toLowerCase().split(/\s+/).filter(function (t) {
        return t !== "";
    });
    if (!tokens.length)
        return rows;
    return rows.filter(function (r) {
        var hay = searchText(r, tr);
        return tokens.every(function (t) {
            return hay.indexOf(t) !== -1;
        });
    });
}

// Cheatsheet view: rows with the same title and actions (e.g. "Focus Up"
// on Up and on K) become one row listing every combo; `uids` keeps the
// originals (the first one is edited).
function mergeRows(rows, tr) {
    var byKey = {};
    var out = [];
    rows.forEach(function (r) {
        var id = title(r, tr) + "\u0000" + r.enabled + "\u0000" + JSON.stringify(r.actions.map(function (a) {
            return [a.id, a.args];
        }));
        var m = byKey[id];
        if (!m) {
            m = byKey[id] = Object.assign({}, r, {
                "keys": r.keys.slice(),
                "uids": [r.uid]
            });
            out.push(m);
            return;
        }
        m.keys = m.keys.concat(r.keys);
        m.uids.push(r.uid);
    });
    return out;
}

// [{group: GROUPS entry, rows}] in GROUPS order, empty groups dropped
// unless `keepEmpty`.
function grouped(rows, keepEmpty) {
    return GROUPS.map(function (g) {
        return {
            "group": g,
            "rows": rows.filter(function (r) {
                return r.group === g.id;
            })
        };
    }).filter(function (x) {
        return keepEmpty || x.rows.length > 0;
    });
}

// Distributes groups over `n` columns, keeping order within a column and
// balancing the height (a group weighs its rows + a header).
function columns(groups, n) {
    var count = Math.max(1, n | 0);
    var cols = [];
    var heights = [];
    for (var i = 0; i < count; i++) {
        cols.push([]);
        heights.push(0);
    }
    groups.forEach(function (g) {
        var best = 0;
        for (var c = 1; c < count; c++) {
            if (heights[c] < heights[best])
                best = c;
        }
        cols[best].push(g);
        heights[best] += g.rows.length + 2;
    });
    return cols.filter(function (c) {
        return c.length > 0;
    });
}

// --- Conflicts -------------------------------------------------------------

function layoutsOf(row) {
    var all = false;
    var set = {};
    row.actions.forEach(function (a) {
        if (!a.layouts || !a.layouts.length)
            all = true;
        else
            a.layouts.forEach(function (l) {
                set[l] = true;
            });
    });
    return all ? LAYOUTS.slice() : Object.keys(set);
}

function overlaps(a, b) {
    return a.some(function (x) {
        return b.indexOf(x) !== -1;
    });
}

function isRelease(action) {
    var entry = Actions.getActionById(action.id);
    var flags = entry && entry.id !== "legacy.dispatcher" ? (entry.flags || "") : ((action.args && action.args.flags) || "");
    return flags.indexOf("r") !== -1;
}

// Hyprland binds this shell may render, by "comboId#press|release" (see
// backend/pkg/svc/compositor/toml.go: one bind per key x action, plus a
// release bind for hold actions). Layout-restricted actions are counted in
// every layout: the compositor may still hold the previous layout's set.
function renderedCounts(rows) {
    var counts = {};
    function add(id) {
        counts[id] = (counts[id] || 0) + 1;
    }
    rows.forEach(function (row) {
        if (!row.enabled)
            return;
        row.keys.forEach(function (k) {
            var combo = KeyNames.comboId(k.modifiers, k.key);
            if (!combo)
                return;
            row.actions.forEach(function (a) {
                var release = isRelease(a);
                add(combo + (release ? "#release" : "#press"));
                var entry = Actions.getActionById(a.id);
                if (entry && entry.hold && !release)
                    add(combo + "#release");
            });
        });
    });
    return counts;
}

// Native binds: hyprctl binds -j entries (other submaps ignored). A bind
// with a description is the user's own compositor config (the shell's
// binds carry none); undescribed ones beyond what the shell renders on
// that combo are native too.
function nativeBinds(hypr, rows) {
    var ours = renderedCounts(rows);
    var seen = {};
    var out = [];
    (hypr || []).forEach(function (b) {
        if (!b || b.submap || !b.key)
            return;
        var combo = KeyNames.comboId(KeyNames.modsFromMask(b.modmask || 0), b.key);
        if (!combo)
            return;
        var slot = combo + (b.release ? "#release" : "#press");
        var described = !!(b.has_description && b.description);
        if (!described) {
            seen[slot] = (seen[slot] || 0) + 1;
            if (seen[slot] <= (ours[slot] || 0))
                return;
        }
        out.push({
            "combo": combo,
            "modifiers": KeyNames.modsFromMask(b.modmask || 0),
            "key": b.key,
            "text": described ? b.description : ((b.dispatcher || "") + (b.arg ? " " + b.arg : ""))
        });
    });
    return out;
}

// uid -> [{kind: "bind", uid} | {kind: "native", text}] for every enabled
// row sharing a combo (and a layout) with another enabled row or with a
// native compositor bind.
function findConflicts(rows, native) {
    var byCombo = {};
    rows.forEach(function (row) {
        if (!row.enabled)
            return;
        var layouts = layoutsOf(row);
        var seenHere = {};
        row.keys.forEach(function (k) {
            var combo = KeyNames.comboId(k.modifiers, k.key);
            if (!combo || seenHere[combo])
                return;
            seenHere[combo] = true;
            (byCombo[combo] = byCombo[combo] || []).push({
                "row": row,
                "layouts": layouts
            });
        });
    });
    var out = {};
    function push(uid, item) {
        var list = out[uid] = out[uid] || [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].kind === item.kind && list[i].uid === item.uid && list[i].text === item.text)
                return;
        }
        list.push(item);
    }
    Object.keys(byCombo).forEach(function (combo) {
        var list = byCombo[combo];
        for (var i = 0; i < list.length; i++) {
            for (var j = i + 1; j < list.length; j++) {
                if (!overlaps(list[i].layouts, list[j].layouts))
                    continue;
                push(list[i].row.uid, {
                    "kind": "bind",
                    "uid": list[j].row.uid,
                    "combo": combo
                });
                push(list[j].row.uid, {
                    "kind": "bind",
                    "uid": list[i].row.uid,
                    "combo": combo
                });
            }
        }
    });
    (native || []).forEach(function (n) {
        (byCombo[n.combo] || []).forEach(function (x) {
            push(x.row.uid, {
                "kind": "native",
                "text": n.text,
                "combo": n.combo
            });
        });
    });
    return out;
}

// Rows (not `except`) using the combo, for the recorder's live warning.
function rowsUsing(rows, mods, key, exceptUid) {
    var combo = KeyNames.comboId(mods, key);
    if (!combo)
        return [];
    return rows.filter(function (r) {
        return r.enabled && r.uid !== exceptUid && r.keys.some(function (k) {
            return KeyNames.comboId(k.modifiers, k.key) === combo;
        });
    });
}

// --- Edits ----------------------------------------------------------------

function isCoreModified(row, current) {
    var entry = CoreBinds.byPath(row.path);
    if (!entry)
        return false;
    var def = CoreBinds.defaultBind(entry);
    var k = row.keys[0] || keyOf(null);
    var a = row.actions[0] || {};
    return KeyNames.comboId(k.modifiers, k.key) !== KeyNames.comboId(def.modifiers, def.key) || a.id !== def.action.id || JSON.stringify(a.args || {}) !== JSON.stringify(def.action.args) || !row.enabled;
}

// Custom bind as stored in binds.json.
function customBind(name, keys, actions, enabled) {
    return {
        "name": name || "",
        "keys": (keys || []).map(keyOf),
        "actions": (actions || []).map(function (a) {
            return {
                "id": a.id,
                "args": plain(a.args) || {},
                "layouts": (a.layouts || []).slice()
            };
        }),
        "enabled": enabled !== false
    };
}

// New custom bind (default action: open an app, the usual case).
function newCustom(actionId) {
    var id = actionId || "apps.launch";
    return customBind("", [{
            "modifiers": ["SUPER"],
            "key": ""
        }], [{
            "id": id,
            "args": Actions.defaultArgs(id),
            "layouts": []
        }], true);
}

function customList(list) {
    return Array.prototype.map.call(list || [], function (b) {
        return plain(b);
    });
}

// Copy of `list` with the bind at `index` merged with `patch`.
function withCustom(list, index, patch) {
    var out = customList(list);
    if (index < 0 || index >= out.length)
        return out;
    var next = out[index] || {};
    for (var k in patch)
        next[k] = plain(patch[k]);
    out[index] = next;
    return out;
}

function withoutCustom(list, index) {
    var out = customList(list);
    if (index >= 0 && index < out.length)
        out.splice(index, 1);
    return out;
}

function withAddedCustom(list, bind) {
    var out = customList(list);
    out.push(plain(bind));
    return out;
}

// Disabled core paths with `path` switched on/off.
function withDisabled(disabled, path, on) {
    var out = Array.prototype.slice.call(disabled || []).filter(function (p) {
        return p !== path;
    });
    if (!on)
        out.push(path);
    return out;
}
