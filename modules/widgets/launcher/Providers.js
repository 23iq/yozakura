.pragma library

// Launcher result providers: one entry per provider, one QML file per
// provider (providers/<File>.qml). Adding a provider = one file + one entry
// here (+ its id in config/defaults/prefix.js `launcher.order`).
//
//   kind     "inline": results shown in the launcher list
//            "tab":    a prefix that switches to a launcher tab (clipboard...)
//   file     provider component, relative to this directory
//   prefix   key of the prefix in Config.prefix ("" = no prefix)
//   mixed    queried for normal searches (no prefix typed)
//   empty    queried when the search is empty
//   tab      StackLayout index of a tab provider (LauncherView)
var PROVIDERS = [
    {
        "id": "calculator",
        "kind": "inline",
        "file": "providers/CalculatorProvider.qml",
        "icon": "calculator",
        "prefix": "calculator",
        "mixed": true
    },
    {
        "id": "commands",
        "kind": "inline",
        "file": "providers/CommandsProvider.qml",
        "icon": "command",
        "prefix": "commands",
        "mixed": true
    },
    {
        "id": "apps",
        "kind": "inline",
        "file": "providers/AppsProvider.qml",
        "icon": "apps",
        "prefix": "",
        "mixed": true,
        "empty": true
    },
    {
        "id": "specials",
        "kind": "inline",
        "file": "providers/SpecialsProvider.qml",
        "icon": "cube",
        "prefix": "",
        "mixed": true
    },
    {
        "id": "wallpapers",
        "kind": "inline",
        "file": "providers/WallpapersProvider.qml",
        "icon": "image",
        "prefix": "wallpapers",
        "mixed": false
    },
    {
        "id": "files",
        "kind": "inline",
        "file": "providers/FilesProvider.qml",
        "icon": "folder",
        "prefix": "files",
        "mixed": true
    },
    {
        "id": "ai",
        "kind": "inline",
        "file": "providers/AiProvider.qml",
        "icon": "sparkle",
        "prefix": "ai",
        "mixed": true
    },
    {
        "id": "clipboard",
        "kind": "tab",
        "icon": "clipboard",
        "prefix": "clipboard",
        "tab": 1
    },
    {
        "id": "emoji",
        "kind": "tab",
        "icon": "emoji",
        "prefix": "emoji",
        "tab": 2
    },
    {
        "id": "tmux",
        "kind": "tab",
        "icon": "terminal",
        "prefix": "tmux",
        "tab": 3
    },
    {
        "id": "notes",
        "kind": "tab",
        "icon": "note",
        "prefix": "notes",
        "tab": 4
    }
];

var INLINE_IDS = PROVIDERS.filter(p => p.kind === "inline").map(p => p.id);
var TAB_IDS = PROVIDERS.filter(p => p.kind === "tab").map(p => p.id);

function byId(id) {
    for (let i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].id === id)
            return PROVIDERS[i];
    }
    return null;
}

function _list(v) {
    if (!v)
        return [];
    const out = [];
    for (let i = 0; i < v.length; i++)
        out.push(String(v[i]));
    return out;
}

function isEnabled(id, disabled) {
    return _list(disabled).indexOf(id) === -1 && byId(id) !== null;
}

// Inline provider ids in the configured order: unknown ids are dropped,
// providers missing from the order (new ones) are appended in registry order.
function ordered(order) {
    const out = [];
    _list(order).forEach(id => {
        const p = byId(id);
        if (p && p.kind === "inline" && out.indexOf(id) === -1)
            out.push(id);
    });
    INLINE_IDS.forEach(id => {
        if (out.indexOf(id) === -1)
            out.push(id);
    });
    return out;
}

// Enabled inline providers in order.
function active(order, disabled) {
    return ordered(order).filter(id => isEnabled(id, disabled));
}

// Moves `id` by `delta` places inside the full order; returns a new array.
function move(order, id, delta) {
    const out = ordered(order);
    const i = out.indexOf(id);
    const j = i + delta;
    if (i < 0 || j < 0 || j >= out.length)
        return out;
    out.splice(i, 1);
    out.splice(j, 0, id);
    return out;
}

// Toggles `id` in the disabled list; returns a new array.
function setEnabled(disabled, id, on) {
    const out = _list(disabled).filter(x => x !== id);
    if (!on)
        out.push(id);
    return out;
}

// Word prefixes ("ff") need a space after them; symbol prefixes (">", "?")
// work glued to the query ("?why").
function needsSpace(prefix) {
    return /^[A-Za-z0-9]/.test(prefix || "");
}

// The query after `prefix`, or null when `text` does not start with it.
function stripPrefix(text, prefix) {
    if (!prefix)
        return null;
    text = text || "";
    if (needsSpace(prefix)) {
        if (text.indexOf(prefix + " ") !== 0)
            return null;
        return text.substring(prefix.length + 1);
    }
    if (text.indexOf(prefix) !== 0)
        return null;
    return text.substring(prefix.length).replace(/^\s+/, "");
}

// What to query for `text`. `prefixes` maps a prefix key to its value
// (Config.prefix). Returns {mode: "prefix"|"mixed"|"empty", providers:
// [{id, query}]}; a prefix always wins over mixed search, the longest
// matching prefix first.
function route(text, prefixes, order, disabled) {
    prefixes = prefixes || {};
    const enabled = active(order, disabled);
    const candidates = enabled.map(id => ({
                "id": id,
                "prefix": prefixes[byId(id).prefix] || ""
            })).filter(c => c.prefix !== "").sort((a, b) => b.prefix.length - a.prefix.length);
    for (let i = 0; i < candidates.length; i++) {
        const rest = stripPrefix(text, candidates[i].prefix);
        if (rest !== null)
            return {
                "mode": "prefix",
                "providers": [
                    {
                        "id": candidates[i].id,
                        "query": rest
                    }
                ]
            };
    }
    if (!text || text.trim() === "")
        return {
            "mode": "empty",
            "providers": enabled.filter(id => byId(id).empty).map(id => ({
                        "id": id,
                        "query": ""
                    }))
        };
    return {
        "mode": "mixed",
        "providers": enabled.filter(id => byId(id).mixed).map(id => ({
                    "id": id,
                    "query": text
                }))
    };
}

// Tab index for a text that is exactly "<tab prefix> ", else 0.
function detectTab(text, prefixes, disabled) {
    prefixes = prefixes || {};
    for (let i = 0; i < PROVIDERS.length; i++) {
        const p = PROVIDERS[i];
        if (p.kind !== "tab" || !isEnabled(p.id, disabled))
            continue;
        const pre = prefixes[p.prefix];
        if (pre && text === pre + " ")
            return p.tab;
    }
    return 0;
}

// True when `text` still starts with any tab prefix + space.
function startsWithTabPrefix(text, prefixes) {
    prefixes = prefixes || {};
    return PROVIDERS.some(p => p.kind === "tab" && prefixes[p.prefix] && (text || "").indexOf(prefixes[p.prefix] + " ") === 0);
}

// The tab provider of a StackLayout index.
function tabProvider(index) {
    for (let i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].kind === "tab" && PROVIDERS[i].tab === index)
            return PROVIDERS[i];
    }
    return null;
}
