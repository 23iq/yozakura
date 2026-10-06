.pragma library
.import "../extras/ExtrasModel.js" as ExtrasModel

// Pure helpers of the onboarding summary (StepFinish; tests in
// tests/onboarding-finish.test.cjs): one short line per card and the live
// state of the installs the wizard queued.

// Catalog categories counted as AI on the summary (the voice entry has
// its own card).
var AI_CATEGORIES = ["agents", "localai", "gpu"];
var VOICE_ID = "voice";

function _entry(catalog, id) {
    var list = catalog && catalog.entries ? catalog.entries : [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i];
    }
    return null;
}

// Queued ids split by summary card: {apps, ai, voice} (unknown ids are apps).
function splitInstalls(ids, catalog) {
    var out = {
        "apps": [],
        "ai": [],
        "voice": []
    };
    (ids || []).forEach(function (id) {
        var e = _entry(catalog, id);
        if (id === VOICE_ID)
            out.voice.push(id);
        else if (e && AI_CATEGORIES.indexOf(e.category) !== -1)
            out.ai.push(id);
        else
            out.apps.push(id);
    });
    return out;
}

// Live state of a set of queued entries: counts per card state and the
// mean percent of the running ones (-1: none running or unknown).
function installSummary(ids, status, progress) {
    var out = {
        "total": 0,
        "installed": 0,
        "installing": 0,
        "failed": 0,
        "percent": -1
    };
    var sum = 0;
    var known = 0;
    (ids || []).forEach(function (id) {
        var p = progress ? progress[id] : null;
        var st = ExtrasModel.cardState(status ? status[id] : null, p);
        out.total++;
        if (st === "installed")
            out.installed++;
        else if (st === "installing") {
            out.installing++;
            if (p && p.state === "running" && p.percent >= 0) {
                sum += p.percent;
                known++;
            }
        } else if (st === "failed")
            out.failed++;
    });
    if (known > 0)
        out.percent = Math.round(sum / known);
    return out;
}

// "2560×1440 · 165 Hz" for the first enabled monitor, "+N" for the others.
function displaysLine(configs) {
    var on = (configs || []).filter(function (c) {
        return c && c.enabled !== false && c.width > 0;
    });
    if (on.length === 0)
        return "";
    var c = on[0];
    var line = c.width + "×" + c.height + " · " + Math.round(c.refresh || 0) + " Hz";
    return on.length > 1 ? line + "  +" + (on.length - 1) : line;
}

// "US · RU · DE(intl)" from Config.keyboard.layouts.
function layoutsLine(layouts) {
    return Array.from(layouts || []).map(function (l) {
        var code = String(l && l.layout || "").toUpperCase();
        return l && l.variant ? code + "(" + l.variant + ")" : code;
    }).filter(function (s) {
        return s !== "";
    }).join(" · ");
}

// Names of the installed AI entries (agents, Ollama), catalog order.
function installedAi(catalog, status) {
    var list = catalog && catalog.entries ? catalog.entries : [];
    return list.filter(function (e) {
        return !e.hidden && e.id !== VOICE_ID && (e.category === "agents" || e.category === "localai") && status && status[e.id] && status[e.id].state === "installed";
    }).map(function (e) {
        return e.name;
    });
}
