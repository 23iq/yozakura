.pragma library

// Special workspaces (Hyprland scratchpads): the pure logic shared by
// SpecialsService (launch/move/rename), the settings editor, the onboarding
// step, the launcher provider, the dashboard list, the bar indicator and the
// keybinds model. No QML, no I/O. Tested in tests/specials.test.cjs; the
// Go side (backend/pkg/specials) mirrors hyprName() (parity fixture
// tests/fixtures/special-names.json).
//
// Item (config specials.workspaces[]):
//   {id, name, icon, accent, toggle: {modifiers, key}, send: {modifiers, key},
//    preload, apps: [{id, name, icon, match, command, ifRunning, rule}]}

// Compositors with named special workspaces; elsewhere the feature hides.
var COMPOSITORS = ["hyprland"];

var IF_RUNNING = ["nothing", "move"];

// Accents are palette roles (never hex), so every wallpaper/preset works.
var ACCENTS = ["primary", "secondary", "tertiary", "error", "red", "yellow", "green", "cyan", "blue", "magenta"];

// Icons glyph names offered by the pickers (modules/theme/Icons.qml).
var ICONS = ["stack", "chatDots", "telegram", "chatTeardrop", "musicNotes", "spotify", "headphones", "code", "terminal", "gitBranch", "notePencil", "note", "globe", "folder", "calendar", "listChecks", "gamepad", "lightbulb", "heart", "starIcon", "brain"];

var MAX_NAME = 32;

// Quick templates (onboarding + settings). `name` is a translation key
// (custom ones get "Special N"); `apps` are desktop ids suggested when
// installed, first match per group wins.
var TEMPLATES = [
    { "id": "chat", "name": "specials.template.chat", "icon": "chatDots", "accent": "primary", "apps": [["org.telegram.desktop", "telegramdesktop"], ["vesktop", "dev.vencord.Vesktop", "discord", "com.discordapp.Discord"]] },
    { "id": "music", "name": "specials.template.music", "icon": "musicNotes", "accent": "tertiary", "apps": [["spotify", "com.spotify.Client", "spotify-launcher"]] },
    { "id": "dev", "name": "specials.template.dev", "icon": "code", "accent": "secondary", "apps": [] },
    { "id": "notes", "name": "specials.template.notes", "icon": "notePencil", "accent": "yellow", "apps": [["obsidian", "md.obsidian.Obsidian", "org.gnome.TextEditor"]] },
    { "id": "custom", "name": "", "icon": "stack", "accent": "primary", "apps": [] }
];

function supported(compositor) {
    return COMPOSITORS.indexOf(String(compositor || "")) !== -1;
}

function plain(v) {
    return v === undefined || v === null ? v : JSON.parse(JSON.stringify(v));
}

function list(v) {
    if (!v)
        return [];
    var out = [];
    for (var i = 0; i < v.length; i++)
        out.push(v[i]);
    return out;
}

// Characters Hyprland's dispatcher/rule syntax gives a meaning to (and
// whitespace) become "-": names stay readable, Unicode letters survive.
var UNSAFE = /[\s,:;\[\]"'`\\\/$|&(){}<>*?#!=%@^~+]+/g;

function sanitizeName(name) {
    var s = String(name === undefined || name === null ? "" : name).trim();
    s = s.replace(UNSAFE, "-").replace(/-+/g, "-").replace(/^[-.]+|[-.]+$/g, "");
    var chars = Array.from(s);
    if (chars.length > MAX_NAME)
        s = chars.slice(0, MAX_NAME).join("").replace(/[-.]+$/, "");
    return s;
}

// Hyprland names (special:<name>) of every item by id, unique within the
// list (a clash gets "-2", "-3", ... in list order).
function hyprNames(items) {
    var out = {};
    var used = {};
    list(items).forEach(function (it, i) {
        var base = sanitizeName(it && it.name) || ("special-" + (i + 1));
        var name = base;
        var n = 2;
        while (used[name.toLowerCase()])
            name = base + "-" + (n++);
        used[name.toLowerCase()] = true;
        out[(it && it.id) || ("#" + i)] = name;
    });
    return out;
}

function hyprName(items, id) {
    return hyprNames(items)[id] || "";
}

function byId(items, id) {
    var l = list(items);
    for (var i = 0; i < l.length; i++) {
        if (l[i] && l[i].id === id)
            return l[i];
    }
    return null;
}

// The item a Hyprland special name (with or without "special:") belongs to.
function byHyprName(items, name) {
    var n = String(name || "").replace(/^special:/, "");
    var names = hyprNames(items);
    var l = list(items);
    for (var i = 0; i < l.length; i++) {
        if (names[l[i].id] === n)
            return l[i];
    }
    return null;
}

function slug(name) {
    var s = sanitizeName(name).toLowerCase().replace(/[^a-z0-9_-]+/g, "");
    return s || "special";
}

function newId(items, name) {
    var ids = {};
    list(items).forEach(function (it) {
        ids[it.id] = true;
    });
    var base = slug(name);
    var id = base;
    var n = 2;
    while (ids[id])
        id = base + "-" + (n++);
    return id;
}

// "Special 1", "Special 2", ... : the first number not taken by a name.
function defaultName(items, tr) {
    var names = {};
    list(items).forEach(function (it) {
        names[String(it.name || "").toLowerCase()] = true;
    });
    var n = 1;
    var name;
    do {
        name = tr ? tr("specials.default_name", n) : "Special " + n;
        n++;
    } while (names[name.toLowerCase()]);
    return name;
}

function template(id) {
    for (var i = 0; i < TEMPLATES.length; i++) {
        if (TEMPLATES[i].id === id)
            return TEMPLATES[i];
    }
    return TEMPLATES[TEMPLATES.length - 1];
}

function emptyCombo() {
    return {
        "modifiers": [],
        "key": ""
    };
}

function combo(c) {
    return {
        "modifiers": c && c.modifiers ? list(c.modifiers).map(String) : [],
        "key": c && c.key ? String(c.key) : ""
    };
}

// Desktop Exec field codes (%f %U %i ...) removed; "%%" is a literal "%".
function stripFieldCodes(exec) {
    return String(exec || "").replace(/%%/g, "\u0000").replace(/\s*%[fFuUdDnNickvm]/g, "").replace(/\u0000/g, "%").trim();
}

function desktopId(id) {
    return String(id || "").replace(/\.desktop$/, "");
}

// App entry from a desktop entry ({id, name, icon, execString|command,
// startupClass}): the class comes from StartupWMClass, else the app id.
function appFromEntry(entry) {
    var e = entry || {};
    var id = desktopId(e.id);
    return {
        "id": id,
        "name": String(e.name || id),
        "icon": String(e.icon || id),
        "match": String(e.startupClass || id),
        "command": stripFieldCodes(e.command || e.execString || ""),
        "ifRunning": "nothing",
        "rule": false
    };
}

function normalizeApp(a) {
    var app = a || {};
    return {
        "id": String(app.id || ""),
        "name": String(app.name || app.id || app.match || ""),
        "icon": String(app.icon || ""),
        "match": String(app.match || app.id || ""),
        "command": String(app.command || ""),
        "ifRunning": IF_RUNNING.indexOf(app.ifRunning) !== -1 ? app.ifRunning : "nothing",
        "rule": app.rule === true
    };
}

function normalize(item) {
    var it = item || {};
    return {
        "id": String(it.id || ""),
        "name": String(it.name || ""),
        "icon": it.icon && typeof it.icon === "string" ? it.icon : "stack",
        "accent": ACCENTS.indexOf(it.accent) !== -1 ? it.accent : "primary",
        "toggle": combo(it.toggle),
        "send": combo(it.send),
        "preload": it.preload === true,
        "apps": list(it.apps).map(normalizeApp)
    };
}

// A new item from a template. `available(desktopId)` returns a desktop
// entry (or null) for the template's suggested apps.
function create(items, templateId, tr, available) {
    var t = template(templateId);
    var name = t.name ? (tr ? tr(t.name) : t.id) : defaultName(items, tr);
    var taken = {};
    list(items).forEach(function (it) {
        taken[String(it.name).toLowerCase()] = true;
    });
    if (taken[name.toLowerCase()])
        name = defaultName(items, tr);
    var apps = [];
    t.apps.forEach(function (group) {
        for (var i = 0; i < group.length; i++) {
            var e = available ? available(group[i]) : null;
            if (e) {
                apps.push(appFromEntry(e));
                break;
            }
        }
    });
    return normalize({
        "id": newId(items, name),
        "name": name,
        "icon": t.icon,
        "accent": t.accent,
        "apps": apps
    });
}

// --- Edits (pure: return a new list) --------------------------------------

function withItem(items, id, patch) {
    return list(items).map(function (it) {
        return it.id === id ? Object.assign(normalize(it), plain(patch)) : plain(it);
    });
}

function withoutItem(items, id) {
    return list(items).filter(function (it) {
        return it.id !== id;
    }).map(plain);
}

function withApp(items, id, app) {
    var it = byId(items, id);
    if (!it)
        return list(items).map(plain);
    var apps = list(it.apps).map(plain);
    var a = normalizeApp(app);
    if (apps.some(function (x) {
        return x.match === a.match && x.id === a.id;
    }))
        return list(items).map(plain);
    apps.push(a);
    return withItem(items, id, { "apps": apps });
}

function withAppPatch(items, id, index, patch) {
    var it = byId(items, id);
    if (!it)
        return list(items).map(plain);
    var apps = list(it.apps).map(plain);
    if (index < 0 || index >= apps.length)
        return list(items).map(plain);
    apps[index] = normalizeApp(Object.assign({}, apps[index], plain(patch)));
    return withItem(items, id, { "apps": apps });
}

function withoutApp(items, id, index) {
    var it = byId(items, id);
    if (!it)
        return list(items).map(plain);
    var apps = list(it.apps).map(plain);
    apps.splice(index, 1);
    return withItem(items, id, { "apps": apps });
}

// Problems a list has (shown in settings, checked by the CLI): empty name,
// two items with the same Hyprland name after sanitizing.
function problems(items) {
    var out = [];
    var seen = {};
    list(items).forEach(function (it) {
        var n = sanitizeName(it.name).toLowerCase();
        if (!n)
            out.push({ "id": it.id, "kind": "empty" });
        else if (seen[n])
            out.push({ "id": it.id, "kind": "duplicate", "other": seen[n] });
        else
            seen[n] = it.id;
    });
    return out;
}

// --- Windows ---------------------------------------------------------------

function classMatches(pattern, cls) {
    var p = String(pattern || "");
    var c = String(cls || "");
    if (!p || !c)
        return false;
    if (p.toLowerCase() === c.toLowerCase())
        return true;
    try {
        return new RegExp("^(?:" + p + ")$", "i").test(c);
    } catch (e) {
        return false;
    }
}

// The special a client is on ("" for a normal workspace). yozd reports the
// workspace as a numeric id (special ones are negative) or, right after a
// move event, by name ("special:X").
function windowSpecial(client, workspaces) {
    var ws = client && client.workspace ? client.workspace : {};
    var name = String(ws.name || "");
    if (name.indexOf("special:") === 0)
        return name.substring(8);
    var id = Number(ws.id);
    if (!(id < 0))
        return "";
    var l = list(workspaces);
    for (var i = 0; i < l.length; i++) {
        if (Number(l[i].id) === id) {
            var n = String(l[i].name || "");
            return n.indexOf("special:") === 0 ? n.substring(8) : "";
        }
    }
    return "";
}

// The clients a monitor shows: those on its open special (Hyprland keeps
// the normal workspace active underneath one) or else on its active
// workspace. `specialName` is the open special's name without "special:".
function visibleClients(clients, workspaces, activeWorkspaceId, specialName) {
    if (specialName)
        return list(clients).filter(function (c) {
            return windowSpecial(c, workspaces) === specialName;
        });
    return list(clients).filter(function (c) {
        return c && c.workspace && c.workspace.id === activeWorkspaceId;
    });
}

// [{address, class, special}] from YozdService clients + workspaces.
function windowsOf(clients, workspaces) {
    return list(clients).map(function (c) {
        return {
            "address": String(c.address || ""),
            "class": String(c.class || ""),
            "special": windowSpecial(c, workspaces)
        };
    });
}

function counts(windows) {
    var out = {};
    list(windows).forEach(function (w) {
        if (w.special)
            out[w.special] = (out[w.special] || 0) + 1;
    });
    return out;
}

function appKey(itemId, app) {
    return itemId + "/" + (app.id || app.match);
}

// What opening a special does: [{kind: "launch", key, app} | {kind: "move",
// address}]. `pending` maps appKey -> deadline (ms); an app still pending
// is never launched again (apps can take seconds to map a window).
function plan(item, name, windows, pending, now) {
    var out = [];
    var it = normalize(item);
    it.apps.forEach(function (app) {
        if (!app.match && !app.command)
            return;
        var key = appKey(it.id, app);
        var matching = list(windows).filter(function (w) {
            return classMatches(app.match, w.class);
        });
        if (matching.length === 0) {
            var p = pending ? pending[key] : undefined;
            var deadline = p && typeof p === "object" ? p.deadline : p;
            if (app.command && !(deadline && deadline > now))
                out.push({ "kind": "launch", "key": key, "app": app });
            return;
        }
        if (app.ifRunning !== "move")
            return;
        matching.forEach(function (w) {
            if (w.special !== name)
                out.push({ "kind": "move", "address": w.address });
        });
    });
    return out;
}

// Windows launched for a special that did not open there (the exec rule
// matches by pid; single-instance apps often fork): moves for new windows
// of a pending app, and the pending keys that are resolved.
// pending: {key: {deadline, name, match, known: [addresses]}}
function adopt(pending, windows, now) {
    var moves = [];
    var done = [];
    Object.keys(pending || {}).forEach(function (key) {
        var p = pending[key];
        if (!p || p.deadline <= now) {
            done.push(key);
            return;
        }
        var fresh = list(windows).filter(function (w) {
            return classMatches(p.match, w.class) && (p.known || []).indexOf(w.address) === -1;
        });
        if (fresh.length === 0)
            return;
        fresh.forEach(function (w) {
            if (w.special !== p.name)
                moves.push({ "address": w.address, "name": p.name });
        });
        done.push(key);
    });
    return {
        "moves": moves,
        "done": done
    };
}

// Renamed specials: [{from, to}] between two id -> Hyprland name maps.
function renames(before, after) {
    var out = [];
    Object.keys(before || {}).forEach(function (id) {
        if (after[id] && before[id] && after[id] !== before[id])
            out.push({ "from": before[id], "to": after[id] });
    });
    return out;
}

// Addresses of the windows on special `from` (rename migration).
function windowsOn(windows, from) {
    return list(windows).filter(function (w) {
        return w.special === from;
    }).map(function (w) {
        return w.address;
    });
}

// --- Compositor output -----------------------------------------------------

// Persistent window rules for apps with `rule` on (yozd [[window_rules]]).
function windowRules(items) {
    var names = hyprNames(items);
    var out = [];
    list(items).forEach(function (it) {
        list(it.apps).forEach(function (a) {
            var app = normalizeApp(a);
            if (app.rule && app.match)
                out.push({
                    "match": "class:^(" + app.match + ")$",
                    "workspace": "special:" + names[it.id] + " silent"
                });
        });
    });
    return out;
}

var TOGGLE_ACTION = "workspace.toggle-special-named";
var SEND_ACTION = "workspace.move-window-special-named";

// Keybind rows of the specials (modules/keybinds/BindModel.js row shape,
// kind "special"): the cheatsheet, the editor and conflict detection see
// them like any bind; they are edited here, in specials.json.
function bindRows(items) {
    var names = hyprNames(items);
    var out = [];
    list(items).forEach(function (it) {
        [["toggle", TOGGLE_ACTION], ["send", SEND_ACTION]].forEach(function (pair) {
            var k = combo(it[pair[0]]);
            if (!k.key)
                return;
            out.push({
                "uid": "special:" + it.id + ":" + pair[0],
                "kind": "special",
                "path": "",
                "index": -1,
                "specialId": it.id,
                "role": pair[0],
                "keys": [k],
                "actions": [{ "id": pair[1], "args": { "name": names[it.id] }, "layouts": [] }],
                "enabled": true,
                "name": String(it.name || names[it.id]),
                "group": "workspaces"
            });
        });
    });
    return out;
}

// The same binds as binds.json custom entries for the compositor TOML.
function compositorBinds(items) {
    return bindRows(items).map(function (r) {
        return {
            "name": r.name,
            "enabled": true,
            "keys": r.keys,
            "actions": r.actions.map(function (a) {
                return { "id": a.id, "args": a.args };
            })
        };
    });
}

// Launcher search: specials whose name (or Hyprland name) matches, best
// first (exact, prefix, word prefix, contains).
function search(items, query) {
    var q = String(query || "").trim().toLowerCase();
    if (!q)
        return [];
    var names = hyprNames(items);
    var scored = [];
    list(items).forEach(function (it) {
        var best = 0;
        [String(it.name || ""), names[it.id] || ""].forEach(function (n) {
            var l = n.toLowerCase();
            var score = l === q ? 4 : l.indexOf(q) === 0 ? 3 : l.split(/[\s_.-]+/).some(function (w) {
                return w.indexOf(q) === 0;
            }) ? 2 : l.indexOf(q) !== -1 ? 1 : 0;
            best = Math.max(best, score);
        });
        if (best > 0)
            scored.push({ "item": it, "score": best });
    });
    scored.sort(function (a, b) {
        return b.score - a.score || String(a.item.name).localeCompare(String(b.item.name));
    });
    return scored.map(function (x) {
        return x.item;
    });
}
