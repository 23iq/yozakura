.pragma library

// Pure helpers of the Apps & Extras catalog UI (tests/extras-model.test.cjs).
// Catalog / Status / Progress shapes come from the backend `extras` service
// (backend/pkg/svc/extras): entries {id, category, name, icon, size,
// recommended, hidden}, status id -> {state, source, version, reason},
// progress {job, kind, entries, state, percent, phase, reason}.

var UNITS = {
    "B": 1,
    "KB": 1e3,
    "MB": 1e6,
    "GB": 1e9,
    "TB": 1e12
};

// Job kinds whose running job the backend can stop (mirrors qjob.cancellable):
// system / AUR / multilib / upgrade jobs hold the package database.
var CANCELLABLE_KINDS = ["flatpak", "npm", "script", "shell", "ollama"];

// "1.2 GB" -> 1200000000; 0 for anything unreadable.
function parseSize(text) {
    var m = /^\s*([\d.]+)\s*([KMGT]?B)\s*$/i.exec(String(text || ""));
    if (!m)
        return 0;
    var n = parseFloat(m[1]);
    return isNaN(n) ? 0 : n * UNITS[m[2].toUpperCase()];
}

// 1280000000 -> "1.3 GB"; one decimal below 10, none above; "" for 0.
function formatSize(bytes) {
    if (!(bytes > 0))
        return "";
    var order = ["TB", "GB", "MB", "KB"];
    for (var i = 0; i < order.length; i++) {
        var v = bytes / UNITS[order[i]];
        if (v >= 1) {
            var r = v >= 10 ? Math.round(v) : Math.round(v * 10) / 10;
            return r + " " + order[i];
        }
    }
    return Math.round(bytes) + " B";
}

// Human total size of the selected entries ("" when none has a size).
function selectionSize(entries, selected) {
    var total = 0;
    (entries || []).forEach(function (e) {
        if (selected && selected[e.id])
            total += parseSize(e.size);
    });
    return formatSize(total);
}

// Card state of one entry: "installed" | "selectable" | "installing" |
// "failed" | "unavailable". Live progress wins over a status map that has
// not caught up yet; a detected install always wins.
function cardState(status, progress) {
    var st = status ? status.state : "missing";
    if (st === "installed")
        return "installed";
    var p = progress ? progress.state : "";
    if (p === "queued" || p === "running")
        return "installing";
    if (p === "done")
        return "installed";
    if (p === "failed")
        return "failed";
    if (p === "cancelled")
        return st === "unavailable" ? "unavailable" : "selectable";
    if (st === "installing" || st === "failed" || st === "unavailable")
        return st;
    return "selectable";
}

function _inCategory(entry, category) {
    if (!category || (Array.isArray(category) && category.length === 0))
        return true;
    if (Array.isArray(category))
        return category.indexOf(entry.category) !== -1;
    return entry.category === category;
}

function _matches(entry, q, textOf) {
    if (q === "")
        return true;
    var hay = [entry.id, entry.name, entry.category, textOf ? textOf(entry) : ""].join(" ").toLowerCase();
    return q.split(/\s+/).every(function (w) {
        return hay.indexOf(w) !== -1;
    });
}

// Entries to show: never `hidden` ones; entries unavailable here only when
// a search matches them (rendered greyed). `category` is "" (all), an id or
// a list of ids; `textOf(entry)` adds searchable text (translated description).
function visibleEntries(catalog, status, query, category, textOf) {
    if (!catalog || !catalog.entries)
        return [];
    var q = String(query || "").trim().toLowerCase();
    return catalog.entries.filter(function (e) {
        if (e.hidden || !_inCategory(e, category) || !_matches(e, q, textOf))
            return false;
        var st = status && status[e.id] ? status[e.id].state : "missing";
        return st !== "unavailable" || q !== "";
    });
}

// Initial selection: in onboarding the recommended entries that are still
// missing; installed entries are never pre-checked; settings starts empty.
function preselect(catalog, status, mode) {
    var out = {};
    if (mode !== "onboarding" || !catalog || !catalog.entries)
        return out;
    catalog.entries.forEach(function (e) {
        var st = status && status[e.id] ? status[e.id].state : "missing";
        if (e.recommended && !e.hidden && st === "missing")
            out[e.id] = true;
    });
    return out;
}

// Selected ids, in catalog order, whose card is still selectable (not
// installed, installing, failed or unavailable meanwhile).
function selectedIds(catalog, status, progress, selected) {
    if (!catalog || !catalog.entries)
        return [];
    return catalog.entries.filter(function (e) {
        if (!selected || !selected[e.id] || e.hidden)
            return false;
        return cardState(status ? status[e.id] : null, progress ? progress[e.id] : null) === "selectable";
    }).map(function (e) {
        return e.id;
    });
}

// Copy of `map` with `id` flipped (absent = false).
function toggled(map, id) {
    var out = {};
    for (var k in map) {
        if (map[k])
            out[k] = true;
    }
    if (out[id])
        delete out[id];
    else
        out[id] = true;
    return out;
}

// Coded IPC error "<code>: <JSON>" -> {code, data, message}; plain errors
// keep code "" and the text in message.
function parseError(msg) {
    var text = String(msg || "").trim();
    var m = /^([a-z_]+): (\{.*\})$/.exec(text);
    if (m) {
        try {
            return {
                "code": m[1],
                "data": JSON.parse(m[2]),
                "message": ""
            };
        } catch (e) {}
    }
    return {
        "code": "",
        "data": null,
        "message": text
    };
}

// [{category, entries}] in catalog category order, empty groups dropped.
function groupByCategory(catalog, entries) {
    var cats = catalog && catalog.categories ? catalog.categories : [];
    return cats.map(function (c) {
        return {
            "category": c,
            "entries": (entries || []).filter(function (e) {
                return e.category === c.id;
            })
        };
    }).filter(function (g) {
        return g.entries.length > 0;
    });
}

// Queued and running jobs of a job id -> Progress map, running first.
function activeJobs(jobs) {
    var out = [];
    for (var k in jobs || {}) {
        var p = jobs[k];
        if (p && (p.state === "running" || p.state === "queued"))
            out.push(p);
    }
    out.sort(function (a, b) {
        return (a.state === "running" ? 0 : 1) - (b.state === "running" ? 0 : 1);
    });
    return out;
}

// Whether the job can be stopped now (queued always; running only when the
// backend can kill it without leaving the package database locked).
function cancellable(progress) {
    if (!progress)
        return false;
    if (progress.state === "queued")
        return true;
    return progress.state === "running" && CANCELLABLE_KINDS.indexOf(progress.kind) !== -1;
}

// Index of the category in the catalog (0 for unknown): picks its accent.
function accentIndex(catalog, categoryId) {
    var cats = catalog && catalog.categories ? catalog.categories : [];
    for (var i = 0; i < cats.length; i++) {
        if (cats[i].id === categoryId)
            return i;
    }
    return 0;
}

// Phases the backend reports as raw tool output that the UI translates;
// anything else is shown as is.
var PHASE_VERBS = ["downloading", "installing", "building", "resolving", "queued"];

// Raw phase ("Downloading gemini 0.9.1", "installing chromium...") ->
// {key, detail}: key "extras.ui.phase.<verb>" (with ".detail" + %1 when
// detail is set) or "" with the raw text in detail.
function phaseText(phase) {
    var text = String(phase || "").trim();
    var m = /^([a-z]+)\b[\s:]*(.*?)\s*(?:\.\.\.|…)?$/i.exec(text);
    if (!m || PHASE_VERBS.indexOf(m[1].toLowerCase()) === -1)
        return {
            "key": "",
            "detail": text
        };
    var verb = m[1].toLowerCase();
    return {
        "key": "extras.ui.phase." + verb,
        "detail": verb === "resolving" ? "" : m[2]
    };
}

// Reasons a status can give for "unavailable" (backend detect / plan).
var UNAVAILABLE_REASONS = ["only_distro", "no_method", "needs_aur_helper", "needs_flatpak", "needs_npm"];

// i18n key of the unavailable footer for a status reason (%1 = distro name).
function unavailableKey(reason) {
    return "extras.ui.unavailable." + (UNAVAILABLE_REASONS.indexOf(reason) !== -1 ? reason : "only_distro");
}
