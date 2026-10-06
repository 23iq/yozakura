.pragma library

// Pure helpers behind TasksService and the Code task board: status
// metadata, board grouping and order, keyboard navigation, formatting
// (elapsed, cost, tokens), plan edits, `/template` parsing, tasks.create
// params from the composer, notch activity text and the tasks.configure
// payload. Task shape: docs/superpowers/plans/2026-10-06-G1-tasks-backend.md.
// `tr(key)` translates (I18n.t). Tested in tests/ai-tasks-model.test.cjs.

// Board sections, attention first. Queued also holds runs parked until a
// usage limit resets.
var SECTIONS = ["waiting", "running", "review", "queued", "done"];

var STATUS = {
    "queued": { section: "queued", color: "outline", icon: "hourglass", busy: false },
    "waiting_limit": { section: "queued", color: "warning", icon: "hourglass", busy: false },
    "planning": { section: "running", color: "primary", icon: "listChecks", busy: true },
    "running": { section: "running", color: "primary", icon: "circleNotch", busy: true },
    "verifying": { section: "running", color: "primary", icon: "shieldCheck", busy: true },
    "waiting": { section: "waiting", color: "warning", icon: "hand", busy: false },
    "awaiting_plan": { section: "waiting", color: "warning", icon: "listChecks", busy: false },
    "review": { section: "review", color: "secondary", icon: "eye", busy: false },
    "accepted": { section: "done", color: "success", icon: "checkCircle", busy: false },
    "discarded": { section: "done", color: "outline", icon: "trash", busy: false },
    "failed": { section: "done", color: "error", icon: "xCircle", busy: false },
    "cancelled": { section: "done", color: "outline", icon: "stopCircle", busy: false }
};

// Agent id -> provider logo file in assets/aiproviders ("" = glyph).
var AGENT_ICONS = { "claude": "anthropic.svg", "codex": "openai.svg" };

function num(v) {
    var n = Number(v);
    return isNaN(n) ? 0 : n;
}

function statusInfo(status) {
    return STATUS[status] || { section: "running", color: "outline", icon: "circle", busy: false };
}

function sectionOf(status) {
    return statusInfo(status).section;
}

function agentIcon(agent) {
    return AGENT_ICONS[agent] || "";
}

function agentLabel(agent, agents) {
    var list = agents || [];
    for (var i = 0; i < list.length; i++)
        if (list[i] && list[i].id === agent)
            return list[i].label || agent;
    var names = { "claude": "Claude Code", "codex": "Codex", "opencode": "OpenCode" };
    return names[agent] || agent || "";
}

// Agent ids of a task's runs, in run order (best-of-N shows several).
function taskAgents(task) {
    return ((task && task.runs) || []).map(function (r) {
        return r.agent;
    });
}

function inProject(task, dir) {
    if (!dir)
        return true;
    var d = String(dir).replace(/\/+$/, "");
    return !!task && (task.projectDir === d || String(task.projectDir || "").replace(/\/+$/, "") === d);
}

function sortKey(task, section) {
    if (section === "queued")
        return num(task.createdAt);         // execution order: oldest first
    if (section === "running")
        return num(task.startedAt || task.createdAt);
    return -num(task.finishedAt || task.updatedAt || task.createdAt); // newest first
}

// {sections: [{id, tasks, count, collapsed}], total}
// opts: {dir, collapsed: {sectionId: bool}, doneLimit, hideEmpty}
function board(tasks, opts) {
    var o = opts || {};
    var groups = {};
    SECTIONS.forEach(function (s) {
        groups[s] = [];
    });
    var total = 0;
    (tasks || []).forEach(function (t) {
        if (!t || !inProject(t, o.dir))
            return;
        groups[sectionOf(t.status)].push(t);
        total++;
    });
    var collapsed = o.collapsed || {};
    var sections = SECTIONS.map(function (s) {
        var list = groups[s].slice().sort(function (a, b) {
            return sortKey(a, s) - sortKey(b, s);
        });
        var count = list.length;
        if (s === "done" && o.doneLimit > 0)
            list = list.slice(0, o.doneLimit);
        var isCollapsed = collapsed[s] !== undefined ? !!collapsed[s] : s === "done";
        return { id: s, tasks: list, count: count, collapsed: isCollapsed };
    });
    if (o.hideEmpty)
        sections = sections.filter(function (s) {
            return s.count > 0;
        });
    return { sections: sections, total: total };
}

// Visible task ids in board order (collapsed sections skipped).
function order(boardData) {
    var ids = [];
    ((boardData && boardData.sections) || []).forEach(function (s) {
        if (!s.collapsed)
            s.tasks.forEach(function (t) {
                ids.push(t.id);
            });
    });
    return ids;
}

// Next id for J/K (delta +1/-1); the first/last when nothing is selected.
function step(ids, current, delta) {
    if (!ids || ids.length === 0)
        return "";
    var i = ids.indexOf(current);
    if (i < 0)
        return delta < 0 ? ids[ids.length - 1] : ids[0];
    return ids[Math.max(0, Math.min(ids.length - 1, i + delta))];
}

// "45s", "12m", "1h 05m", "2d 3h"
function duration(ms) {
    var s = Math.max(0, Math.floor(num(ms) / 1000));
    if (s < 60)
        return s + "s";
    var m = Math.floor(s / 60);
    if (m < 60)
        return m + "m";
    var h = Math.floor(m / 60);
    if (h < 48)
        return h + "h " + (m % 60 < 10 ? "0" : "") + (m % 60) + "m";
    return Math.floor(h / 24) + "d " + (h % 24) + "h";
}

// Elapsed time of a task: running since startedAt, finished = start..finish.
function elapsed(task, now) {
    if (!task)
        return "";
    var start = num(task.startedAt);
    if (!start)
        return "";
    var end = num(task.finishedAt) || (statusInfo(task.status).section === "done" ? num(task.updatedAt) : now);
    return duration(Math.max(0, end - start));
}

function tokens(n) {
    var v = num(n);
    if (v >= 1e6)
        return (v / 1e6).toFixed(1).replace(/\.0$/, "") + "M";
    if (v >= 1000)
        return (v / 1000).toFixed(1).replace(/\.0$/, "") + "k";
    return String(Math.round(v));
}

// "$0.42", "12.3k tok" or "" when nothing is known.
function cost(task) {
    var c = (task && task.cost) || {};
    if (num(c.costUsd) > 0)
        return "$" + (num(c.costUsd) < 0.1 ? num(c.costUsd).toFixed(3) : num(c.costUsd).toFixed(2));
    var t = num(c.inputTokens) + num(c.outputTokens);
    return t > 0 ? tokens(t) + " tok" : "";
}

function lastCheck(run) {
    var list = (run && run.checks) || [];
    return list.length ? list[list.length - 1] : null;
}

// Worst last-check status over the runs: fail > timeout > pass > skipped > "".
function checkStatus(task) {
    var rank = { "": 0, "skipped": 1, "pass": 2, "timeout": 3, "fail": 4 };
    var best = "";
    ((task && task.runs) || []).forEach(function (r) {
        var c = lastCheck(r);
        var s = c ? c.status : "";
        if ((rank[s] || 0) > (rank[best] || 0))
            best = s;
    });
    return best;
}

function attempts(task) {
    var n = 0;
    ((task && task.runs) || []).forEach(function (r) {
        n = Math.max(n, num(r.attempts));
    });
    return n;
}

// Branch badge: the branch of the first run, "" for in-place tasks.
function branch(task) {
    if (!task || task.inPlace)
        return "";
    var r = (task.runs || [])[0];
    return r && r.branch ? r.branch : "";
}

function changes(run) {
    var c = (run && run.changes) || {};
    return { files: num(c.files), insertions: num(c.insertions), deletions: num(c.deletions), paths: c.paths || [] };
}

// Runs a review can pick from (best-of-N side by side).
function reviewRuns(task) {
    return ((task && task.runs) || []).filter(function (r) {
        return r.status === "review";
    });
}

// The run shown first: a waiting one, else a review one, else the first.
function primaryRun(task) {
    var runs = (task && task.runs) || [];
    for (var i = 0; i < runs.length; i++)
        if (runs[i].status === "waiting" || runs[i].status === "awaiting_plan")
            return runs[i].index !== undefined ? runs[i].index : i;
    for (var j = 0; j < runs.length; j++)
        if (runs[j].status === "review")
            return runs[j].index !== undefined ? runs[j].index : j;
    return runs.length ? (runs[0].index !== undefined ? runs[0].index : 0) : -1;
}

function runAt(task, index) {
    var runs = (task && task.runs) || [];
    for (var i = 0; i < runs.length; i++)
        if ((runs[i].index !== undefined ? runs[i].index : i) === index)
            return runs[i];
    return null;
}

// What the user may do with a task now.
function actions(task) {
    var s = task ? task.status : "";
    var sec = sectionOf(s);
    return {
        accept: s === "review",
        followup: s === "review" || s === "failed" || s === "cancelled" || s === "awaiting_plan",
        discard: s !== "accepted" && s !== "discarded",
        cancel: sec === "running" || sec === "queued" || s === "waiting",
        runPlan: s === "awaiting_plan",
        remove: sec === "done"
    };
}

// ── plan edits (arrays of step strings) ──
function planMove(steps, from, to) {
    var list = (steps || []).slice();
    if (from < 0 || from >= list.length || to < 0 || to >= list.length || from === to)
        return list;
    var item = list.splice(from, 1)[0];
    list.splice(to, 0, item);
    return list;
}

function planRemove(steps, index) {
    var list = (steps || []).slice();
    if (index >= 0 && index < list.length)
        list.splice(index, 1);
    return list;
}

function planInsert(steps, index, text) {
    var list = (steps || []).slice();
    var at = index < 0 || index > list.length ? list.length : index;
    list.splice(at, 0, text || "");
    return list;
}

function planSet(steps, index, text) {
    var list = (steps || []).slice();
    if (index >= 0 && index < list.length)
        list[index] = text;
    return list;
}

function planClean(steps) {
    return (steps || []).map(function (s) {
        return String(s || "").trim();
    }).filter(function (s) {
        return s.length > 0;
    });
}

// ── templates in the composer ──
// Composer suggestions: [{cmd: "/review", desc}]
function slashCommands(templates) {
    return (templates || []).map(function (t) {
        return { cmd: "/" + t.id, desc: t.description || t.name || "" };
    });
}

// "/review the auth module" -> {template: "review", input: "the auth module"}
// when "review" is a known template id, else null.
function parseSlash(text, templates) {
    var m = /^\/([\w.-]+)(?:\s+([\s\S]*))?$/.exec(String(text || "").trim());
    if (!m)
        return null;
    var ids = (templates || []).map(function (t) {
        return t.id;
    });
    if (ids.indexOf(m[1]) < 0)
        return null;
    return { template: m[1], input: (m[2] || "").trim() };
}

// tasks.create params from the composer state.
// opts: {dir, text, attachments, agents: [ids], model, effort, planFirst,
//        inPlace, templates, fallbackAgent}
// Text attachments become <context> blocks (and template vars by kind),
// images are referenced by path.
function createParams(opts) {
    var o = opts || {};
    var agents = (o.agents || []).filter(Boolean);
    var p = { dir: o.dir || "" };
    var vars = {};
    var contexts = [];
    var images = [];
    (o.attachments || []).forEach(function (a) {
        if (!a)
            return;
        if (a.type === "image" && a.path) {
            images.push(a.path);
        } else if (a.text) {
            var name = String(a.name || a.kind || "context").replace(/["<>]/g, "");
            contexts.push('<context name="' + name + '">\n' + a.text + "\n</context>");
            if (a.kind === "selection" || a.kind === "clipboard")
                vars[a.kind] = a.text;
            else if (a.kind === "file")
                vars.file = a.path || a.name || "";
        }
    });
    var slash = parseSlash(o.text, o.templates);
    var body = String(o.text || "").trim();
    if (slash) {
        p.template = slash.template;
        vars.input = slash.input;
        body = slash.input;
    }
    if (images.length)
        contexts.push("Images: " + images.join(", "));
    p.prompt = contexts.length && !slash ? contexts.join("\n\n") + "\n\n" + body : body;
    if (agents.length > 1)
        p.agents = agents.slice(0, 4);
    else if (agents.length === 1)
        p.agent = agents[0];
    if (agents.length <= 1) {
        if (o.model)
            p.model = o.model;
        if (o.effort)
            p.effort = o.effort;
    }
    if (o.planFirst)
        p.mode = "plan";
    if (o.inPlace && agents.length <= 1)
        p.inPlace = true;
    if (Object.keys(vars).length)
        p.vars = vars;
    if (o.fallbackAgent)
        p.fallbackAgent = o.fallbackAgent;
    return p;
}

// Why a composer state cannot become a task ("" = fine).
function createError(opts) {
    var o = opts || {};
    if (!o.dir)
        return "no_project";
    if (!String(o.text || "").trim() && !parseSlash(o.text, o.templates))
        return "empty";
    if ((o.agents || []).length === 0)
        return "no_agent";
    if (o.inPlace && (o.agents || []).length > 1)
        return "in_place_best_of";
    return "";
}

// Notch text of a tasks.activity summary: {label, detail, color, busy} or null.
function activityText(a, tr) {
    if (!a || !a.headline || a.headline === "idle")
        return null;
    var t = tr || function (k) {
        return k;
    };
    var item = null;
    (a.items || []).forEach(function (it) {
        if (it.id === a.taskId)
            item = it;
    });
    var detail = item ? item.title : "";
    switch (a.headline) {
    case "waiting":
        return { label: t("ai.tasks.activity_waiting").replace("%1", a.agent || ""), detail: detail, color: "warning", busy: false, pulse: true };
    case "running":
        return { label: num(a.running) > 1 ? t("ai.tasks.activity_running_n").replace("%1", a.running) : (a.agent || t("ai.tasks.activity_running")), detail: detail, color: "primary", busy: true };
    case "review":
        return { label: num(a.review) > 1 ? t("ai.tasks.activity_review_n").replace("%1", a.review) : t("ai.tasks.activity_review"), detail: detail, color: "secondary", busy: false };
    case "limit":
        return { label: t("ai.tasks.activity_limit"), detail: "", color: "warning", busy: false };
    case "queued":
        return { label: t("ai.tasks.activity_queued").replace("%1", a.queued || 0), detail: "", color: "outline", busy: false };
    }
    return null;
}

// tasks.configure payload from the ai.tasks config.
function configureParams(cfg) {
    var c = cfg || {};
    var events = ["permission", "plan", "review", "failed", "limit"];
    var on = c.notifyEvents || events;
    return {
        maxParallel: Math.max(1, Math.round(num(c.maxParallel) || 2)),
        fallbackAgent: c.fallbackAgent || "",
        notify: c.notifications !== false,
        mute: events.filter(function (e) {
            return on.indexOf(e) < 0;
        }),
        mergeMode: c.mergeMode === "merge" ? "merge" : "squash"
    };
}

// The commit message the review screen starts with.
function commitMessage(task, run) {
    var r = run || null;
    var m = r && r.commitMessage ? String(r.commitMessage).trim() : "";
    return m || (task ? task.title || "" : "");
}
