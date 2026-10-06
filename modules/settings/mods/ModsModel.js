.pragma library

// Pure helpers of the Settings > Mods page (node-tested in
// tests/mods-model.test.cjs). A "mod" is one entry of ModsService.mods.

var SORT_MODES = ["name", "state", "loadOrder"];
var SORT_LABELS = {
    "name": "mods.sort_name",
    "state": "mods.sort_state",
    "loadOrder": "mods.sort_load_order"
};

function dependenciesReady(mod) {
    var deps = (mod && mod.dependencyState) || [];
    for (var i = 0; i < deps.length; i++) {
        if (!deps[i].enabled)
            return false;
    }
    return true;
}

// I18n key of the state chip / row subtitle.
function stateKey(mod) {
    if (!mod)
        return "";
    if (!mod.valid)
        return "mods.package_error";
    if (!mod.compatible)
        return "mods.incompatible";
    return mod.enabled ? "mods.enabled" : "mods.disabled";
}

// "error" | "warning" | "success": the Colors role of the state dot.
function stateTone(mod) {
    if (!mod || !mod.valid || !mod.compatible)
        return "error";
    if (mod.untested && mod.enabled)
        return "warning";
    return mod.enabled ? "success" : "error";
}

// Enabling needs a valid package, a compatible base (or the bypass) and
// every required mod enabled. Disabling is always allowed.
function canToggle(mod, bypassVersionCheck) {
    if (!mod)
        return false;
    if (mod.enabled)
        return true;
    return !!mod.valid && (!!mod.compatible || !!bypassVersionCheck) && dependenciesReady(mod);
}

function matches(mod, query) {
    if (!query)
        return true;
    return String(mod.name || "").toLowerCase().indexOf(query) >= 0 || String(mod.id || "").toLowerCase().indexOf(query) >= 0 || String(mod.description || "").toLowerCase().indexOf(query) >= 0;
}

function filterMods(mods, query, sortMode) {
    var q = String(query || "").trim().toLowerCase();
    var items = (mods || []).filter(function (mod) {
        return matches(mod, q);
    });
    return items.slice().sort(function (a, b) {
        if (sortMode === "loadOrder")
            return (a.order || 0) - (b.order || 0);
        if (sortMode === "state" && !!a.enabled !== !!b.enabled)
            return a.enabled ? -1 : 1;
        return String(a.name || a.id).localeCompare(String(b.name || b.id));
    });
}

// The selected mod, or the first one when the id is unknown.
function selectMod(mods, id) {
    var list = mods || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i];
    }
    return list.length > 0 ? list[0] : null;
}

function nextSort(mode) {
    var i = SORT_MODES.indexOf(mode);
    return SORT_MODES[(i + 1) % SORT_MODES.length];
}

function sortLabelKey(mode) {
    return SORT_LABELS[mode] || SORT_LABELS.name;
}

// Reordering by drag only makes sense over the full, load-ordered list.
function canReorder(sortMode, query) {
    return sortMode === "loadOrder" && String(query || "") === "";
}

// Slot under a dragged row: offset from the list top over the row pitch.
function dropSlot(offset, pitch, count) {
    if (count <= 0 || pitch <= 0)
        return -1;
    return Math.max(0, Math.min(count - 1, Math.round(offset / pitch)));
}

function dependencyKey(dep) {
    if (dep && dep.enabled)
        return "mods.dependency_ready";
    return dep && dep.installed ? "mods.dependency_disabled" : "mods.dependency_missing";
}

// Text input of a mod setting -> {ok, value}. Numbers must be finite.
function parseSettingValue(type, text) {
    var value = text;
    if (type === "integer")
        value = parseInt(text, 10);
    else if (type === "number")
        value = parseFloat(text);
    if (typeof value === "number" && !isFinite(value))
        return {
            "ok": false,
            "value": null
        };
    return {
        "ok": true,
        "value": value
    };
}

function isTextSetting(type) {
    return type === "string" || type === "integer" || type === "number";
}

// Label of the current enum value, or null when no option carries it.
function enumLabel(options, value) {
    var list = options || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].value === value)
            return list[i].label;
    }
    return null;
}

// {value, label, icon} choices for SelectorControl (labels are display text).
function enumChoices(options) {
    return (options || []).map(function (o) {
        return {
            "value": o.value,
            "label": String(o.label !== undefined ? o.label : o.value)
        };
    });
}

// What the status banner reports, most urgent first:
// {kind: "error" | "rebuild" | "restart" | "restartBase" | "key" | "message" | "", text}
function bannerState(s) {
    if (!s)
        return {
            "kind": "",
            "text": ""
        };
    if (s.errorMessage)
        return {
            "kind": "error",
            "text": s.errorMessage
        };
    if (!s.generationCurrent)
        return {
            "kind": "rebuild",
            "text": s.generationError || ""
        };
    if (s.restartRequired)
        return {
            "kind": s.modsEnabled ? "restart" : "restartBase",
            "text": ""
        };
    if (s.statusMessageKey)
        return {
            "kind": "key",
            "text": s.statusMessageKey
        };
    if (s.statusMessage)
        return {
            "kind": "message",
            "text": s.statusMessage
        };
    return {
        "kind": "",
        "text": ""
    };
}

function shortRevision(rev) {
    return String(rev || "").substring(0, 12);
}

function joinList(list) {
    return (list || []).join(", ");
}
