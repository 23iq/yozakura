.pragma library
.import "RoutineTools.js" as Tools

// Pure helpers for routines (backend svc/routines): launcher search, the
// settings editor's edits and labels. A routine:
//   {id, name, icon, keywords, continueOnError, steps: [step]}
//   step: {kind: "action", action, args} | {kind: "tool", tool, args} | {kind: "delay", ms}
// Edits return new objects (QML bindings see the change). Tested in
// tests/routines.test.cjs.

var KINDS = ["action", "tool", "delay"];
var MAX_STEPS = 40;
var MAX_DELAY_MS = 600000;

// Tools a routine may not call (they edit or run routines).
var BLOCKED_TOOLS = { routine_run: true, routine_save: true, routine_delete: true, routines_list: true };

// Icon choices (Icons.* names).
var ICONS = ["lightning", "sun", "moon", "brain", "headphones", "musicNotes", "gamepad", "code", "monitor",
    "bellSlash", "timer", "lightbulb", "calendar", "chatDots", "globe", "terminal", "camera", "heart", "power"];

// Starting points for the editor: name (translation key) + steps.
var TEMPLATES = [
    { id: "focus", name: "routines.template.focus", icon: "brain", steps: [
            { kind: "tool", tool: "focus_start", args: { minutes: 50 } },
            { kind: "tool", tool: "media_control", args: { action: "pause" } }] },
    { id: "night", name: "routines.template.night", icon: "moon", steps: [
            { kind: "tool", tool: "nightlight_set", args: { enabled: true } },
            { kind: "tool", tool: "brightness_set", args: { percent: 40 } },
            { kind: "tool", tool: "dnd_set", args: { enabled: true } }] },
    { id: "meeting", name: "routines.template.meeting", icon: "chatDots", steps: [
            { kind: "tool", tool: "dnd_set", args: { enabled: true } },
            { kind: "tool", tool: "media_control", args: { action: "pause" } },
            { kind: "tool", tool: "caffeine_set", args: { enabled: true } }] },
    { id: "music", name: "routines.template.music", icon: "headphones", steps: [
            { kind: "tool", tool: "audio_output_set", args: { output: "headphones" } },
            { kind: "delay", ms: 1000 },
            { kind: "action", action: "media.play-pause", args: {} }] }
];

// A new routine from a template; tr translates its name.
function fromTemplate(id, tr) {
    for (var i = 0; i < TEMPLATES.length; i++) {
        var t = TEMPLATES[i];
        if (t.id === id) {
            var r = newRoutine(tr ? tr(t.name) : t.name);
            r.icon = t.icon;
            r.steps = clone(t.steps);
            return r;
        }
    }
    return newRoutine("");
}

var clone = Tools.clone;

function newRoutine(name) {
    return { id: "", name: String(name || ""), icon: "lightning", keywords: "", continueOnError: false, steps: [] };
}

// A new step; for a tool step `tool` (a catalog entry) gives the tool and
// its starting arguments, else the tool is left to pick.
function newStep(kind, tool) {
    switch (kind) {
    case "tool":
        return tool ? Tools.newStep(tool) : { kind: "tool", tool: "", args: {} };
    case "delay":
        return { kind: "delay", ms: 1000 };
    }
    return { kind: "action", action: "", args: {} };
}

function withStep(r, step) {
    var out = clone(r);
    out.steps = (out.steps || []).concat([clone(step)]);
    return out;
}

function withStepPatch(r, index, patch) {
    var out = clone(r);
    if (index < 0 || index >= out.steps.length)
        return out;
    for (var k in patch)
        out.steps[index][k] = clone(patch[k]);
    return out;
}

function withoutStep(r, index) {
    var out = clone(r);
    out.steps.splice(index, 1);
    return out;
}

function withMovedStep(r, index, delta) {
    var out = clone(r);
    var j = index + delta;
    if (index < 0 || j < 0 || index >= out.steps.length || j >= out.steps.length)
        return out;
    var s = out.steps.splice(index, 1)[0];
    out.steps.splice(j, 0, s);
    return out;
}

// Duration text of a delay ("500 ms", "2 s", "1.5 min").
function delayText(ms) {
    var v = Number(ms) || 0;
    if (v < 1000)
        return v + " ms";
    if (v < 60000)
        return (Math.round(v / 100) / 10) + " s";
    return (Math.round(v / 6000) / 10) + " min";
}

// Problems that stop a save, as translation keys: [{index, key}]. With the
// tool catalog, tool arguments are checked against their schema too
// ({index, key: "routines.problem.args", field, code, min, max}).
function problems(r, catalog) {
    var tools = catalog ? Tools.byName(catalog) : {};
    var out = [];
    if (!r || !String(r.name || "").trim())
        out.push({ index: -1, key: "routines.problem.name" });
    var steps = (r && r.steps) || [];
    if (steps.length > MAX_STEPS)
        out.push({ index: -1, key: "routines.problem.too_many" });
    for (var i = 0; i < steps.length; i++) {
        var s = steps[i] || {};
        if (KINDS.indexOf(s.kind) < 0)
            out.push({ index: i, key: "routines.problem.kind" });
        else if (s.kind === "action" && !String(s.action || "").trim())
            out.push({ index: i, key: "routines.problem.action" });
        else if (s.kind === "tool" && !String(s.tool || "").trim())
            out.push({ index: i, key: "routines.problem.tool" });
        else if (s.kind === "tool" && BLOCKED_TOOLS[s.tool])
            out.push({ index: i, key: "routines.problem.blocked" });
        else if (s.kind === "delay" && !(s.ms > 0 && s.ms <= MAX_DELAY_MS))
            out.push({ index: i, key: "routines.problem.delay" });
        else if (s.kind === "tool" && tools[s.tool]) {
            var bad = Tools.validate(tools[s.tool], s.args);
            if (bad.length)
                out.push({ index: i, key: "routines.problem.args", field: bad[0].key, code: bad[0].code, min: bad[0].min, max: bad[0].max });
        }
    }
    return out;
}

// Arguments as editable JSON text and back. parseArgs returns
// {ok, value} (value is an object; "" = {}).
function argsText(args) {
    if (!args || Object.keys(args).length === 0)
        return "";
    return JSON.stringify(args);
}

function parseArgs(text) {
    var t = String(text || "").trim();
    if (t === "")
        return { ok: true, value: {} };
    try {
        var v = JSON.parse(t);
        if (v && typeof v === "object" && !Array.isArray(v))
            return { ok: true, value: v };
    } catch (e) {}
    return { ok: false, value: null };
}

// Launcher search over name, id and keywords: prefix > word start > substring.
function search(list, query, limit) {
    var q = String(query || "").trim().toLowerCase();
    var scored = [];
    (list || []).forEach(function (r) {
        var name = String(r.name || "").toLowerCase();
        var hay = name + " " + String(r.id || "") + " " + String(r.keywords || "").toLowerCase();
        var score = 0;
        if (q === "")
            score = 0.1;
        else if (name.indexOf(q) === 0)
            score = 1;
        else if ((" " + hay).indexOf(" " + q) >= 0)
            score = 0.8;
        else if (hay.indexOf(q) >= 0)
            score = 0.5;
        if (score > 0)
            scored.push({ r: r, score: score });
    });
    scored.sort(function (a, b) {
        return b.score - a.score || String(a.r.name).localeCompare(String(b.r.name));
    });
    return scored.slice(0, limit > 0 ? limit : scored.length).map(function (x) {
        return x.r;
    });
}

// One-line summary of a run report ({ok, steps}) for toasts and rows:
// {ok, done, total, failed: {index, label, error} | null}.
function reportSummary(rep) {
    var steps = (rep && rep.steps) || [];
    var done = 0, failed = null;
    steps.forEach(function (s) {
        if (s.status === "ok")
            done++;
        else if (s.status === "failed" && !failed)
            failed = { index: s.index, label: s.label || "", error: s.error || "" };
    });
    return { ok: !!(rep && rep.ok), done: done, total: steps.length, failed: failed };
}

// A step as one sentence ("Turn on Do Not Disturb", "Switch Workspace · 3",
// "Wait 2 s"). catalog: routines.tools; tr(key): translation or "";
// actionLabel(id): the action's label; fallback: the backend's label.
function stepSummary(step, catalog, tr, actionLabel, fallback) {
    var s = step || {};
    switch (s.kind) {
    case "tool":
        return s.tool ? Tools.summary(s, catalog, tr, fallback) : "";
    case "delay":
        return (tr("routines.kind.delay") || "Wait") + " " + delayText(s.ms);
    case "action":
        if (!s.action)
            return "";
        var label = actionLabel ? actionLabel(s.action) : (fallback || s.action);
        var args = s.args || {};
        for (var k in args) {
            if (String(args[k]).trim() !== "")
                return label + " \u00b7 " + args[k];
        }
        return label;
    }
    return fallback || "";
}
