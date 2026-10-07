.pragma library

// Tabs of the preset gallery (popup switcher and settings Presets page):
// Sets | Layout | Style | Palette. Each tab is {id, labelKey, icon, kind}
// plus a model builder in MODELS turning the source data into cards:
//   {key, name, title, subtitle, tags, look, active, official, editable,
//    apply: argv, preview: argv}
// where `apply`/`preview` are `<app> preset ...` args (a preview is undone
// by ["revert"]). The source is {presets: `preset list --json`, parts:
// `preset parts --json`}. A part card applies only its own keys (the
// backend merges them into the live config: `apply --part <kind> <name>`).

var TABS = [
    {
        "id": "sets",
        "labelKey": "presets.tab.sets",
        "icon": "magicWand",
        "kind": ""
    },
    {
        "id": "layout",
        "labelKey": "presets.tab.layout",
        "icon": "squaresFour",
        "kind": "layout"
    },
    {
        "id": "style",
        "labelKey": "presets.tab.style",
        "icon": "paintBrush",
        "kind": "style"
    },
    {
        "id": "palette",
        "labelKey": "presets.tab.palette",
        "icon": "circleHalf",
        "kind": "palette"
    }
];

// `preset parts --json` list of each part kind.
var PART_LISTS = {
    "layout": "layouts",
    "style": "styles",
    "palette": "palettes"
};

function setCards(presets) {
    return (presets || []).map(function (p) {
        return {
            "key": "set:" + p.name,
            "name": p.name,
            "title": p.name,
            "subtitle": p.description || "",
            "tags": p.tags || [],
            "look": p.look || null,
            "active": !!p.active,
            "official": !!p.official,
            "editable": !p.official,
            "apply": ["apply", p.name],
            "preview": ["apply", "--preview", p.name]
        };
    });
}

function partCards(kind, parts) {
    var src = parts || {};
    var current = (src.current || {})[kind] || "";
    return (src[PART_LISTS[kind]] || []).map(function (p) {
        return {
            "key": kind + ":" + p.name,
            "name": p.name,
            "title": p.name,
            "subtitle": p.description || "",
            "tags": p.tags || [],
            "look": p.look || null,
            "active": !!p.active || (current !== "" && current === p.name),
            "official": !!p.official,
            "editable": false,
            "apply": ["apply", "--part", kind, p.name],
            "preview": ["apply", "--part", kind, "--preview", p.name]
        };
    });
}

var MODELS = {
    "sets": function (presets) {
        return setCards(presets);
    },
    "layout": function (presets, src) {
        return partCards("layout", src.parts);
    },
    "style": function (presets, src) {
        return partCards("style", src.parts);
    },
    "palette": function (presets, src) {
        return partCards("palette", src.parts);
    }
};

function ids() {
    return TABS.map(function (t) {
        return t.id;
    });
}

function matches(card, q) {
    if (!q)
        return true;
    var hay = [card.title, card.subtitle].concat(card.tags || []).join(" ").toLowerCase();
    return q.split(/\s+/).every(function (w) {
        return hay.indexOf(w) !== -1;
    });
}

// Cards of tab `id` from `source` ({presets, parts}), filtered by `query`.
function cards(id, source, query) {
    var build = MODELS[id];
    if (!build)
        return [];
    var src = source || {};
    var q = (query || "").trim().toLowerCase();
    return build(src.presets, src).filter(function (c) {
        return matches(c, q);
    });
}

// Index of the active card, else 0 (where the selection starts).
function startIndex(list) {
    for (var i = 0; i < list.length; i++) {
        if (list[i].active)
            return i;
    }
    return 0;
}

// "Yozakura · Sakura · Plum": the current layout, style and palette
// (`parts.current`); an unknown part (edited by hand, a legacy set) reads
// `unknown`.
function currentText(parts, unknown) {
    var cur = (parts || {}).current || {};
    return ["layout", "style", "palette"].map(function (k) {
        return cur[k] || unknown || "?";
    }).join(" · ");
}

// `<app> preset ...` argv of the set actions of the gallery.
function saveArgs(name) {
    return ["save", name];
}

function renameArgs(name, newName) {
    return ["rename", name, newName];
}

function deleteArgs(name) {
    return ["delete", name];
}
