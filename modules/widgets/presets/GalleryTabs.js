.pragma library

// Tabs of the preset switcher gallery. Each tab is {id, labelKey, icon} plus
// a model builder in MODELS turning the source data into cards:
//   {key, title, subtitle, look, active, official, apply: argv, preview: argv}
// where `apply`/`preview` are `<app> preset ...` args (a preview is undone by
// ["revert"]). Add a tab (Layout, Style, Palette...) by adding both.

var TABS = [
    {
        "id": "sets",
        "labelKey": "presets.tab.sets",
        "icon": "magicWand"
    }
];

function setCards(presets) {
    return (presets || []).map(function (p) {
        return {
            "key": "set:" + p.name,
            "title": p.name,
            "subtitle": p.description || "",
            "tags": p.tags || [],
            "look": p.look || null,
            "active": !!p.active,
            "official": !!p.official,
            "apply": ["apply", p.name],
            "preview": ["apply", "--preview", p.name]
        };
    });
}

var MODELS = {
    "sets": setCards
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

// Cards of tab `id` from `source` ({presets: [...]}), filtered by `query`.
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
