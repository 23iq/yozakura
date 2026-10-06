.pragma library
.import "Cron.js" as Cron

// Trigger evaluation for AI automations (pure; AiAutomations.qml wires the
// shell signals). Automation:
//   {id, name, enabled, trigger: {type, cron, pattern, kinds}, prompt, model, output, offer, routine}
// trigger.type: schedule | transfer | clipboard | screenshot | login
// output: notify | sidebar | quickask | clipboard | routine (runs the saved
// routine `routine` deterministically: no prompt, no model)

var TYPES = ["schedule", "transfer", "clipboard", "screenshot", "login"];
var OUTPUTS = ["notify", "sidebar", "quickask", "clipboard", "routine"];

function normalize(a) {
    var t = a && a.trigger ? a.trigger : {};
    return {
        id: String(a && a.id ? a.id : ""),
        name: String(a && a.name ? a.name : ""),
        enabled: !!(a && a.enabled),
        trigger: {
            type: TYPES.indexOf(t.type) >= 0 ? t.type : "schedule",
            cron: String(t.cron || ""),
            pattern: String(t.pattern || ""),
            kinds: Array.isArray(t.kinds) ? t.kinds : []
        },
        prompt: String(a && a.prompt ? a.prompt : ""),
        model: String(a && a.model ? a.model : ""),
        output: OUTPUTS.indexOf(a && a.output) >= 0 ? a.output : "notify",
        offer: a && a.offer !== undefined ? !!a.offer : true,
        routine: String(a && a.routine ? a.routine : "")
    };
}

// A prompt automation needs a prompt; a routine automation its routine.
function runnable(a) {
    return a.output === "routine" ? a.routine !== "" : a.prompt !== "";
}

function active(list, type) {
    var out = [];
    for (var i = 0; i < (list || []).length; i++) {
        var a = normalize(list[i]);
        if (a.enabled && a.trigger.type === type && runnable(a))
            out.push(a);
    }
    return out;
}

// Schedules due at `now` that did not already fire this minute.
function dueSchedules(list, now, lastRuns) {
    var key = Cron.minuteKey(now);
    var due = [];
    var schedules = active(list, "schedule");
    for (var i = 0; i < schedules.length; i++) {
        var a = schedules[i];
        if ((lastRuns || {})[a.id] === key)
            continue;
        if (Cron.matches(a.trigger.cron, now))
            due.push(a);
    }
    return { due: due, key: key };
}

function _regex(pattern) {
    try {
        return new RegExp(pattern, "m");
    } catch (e) {
        return null;
    }
}

// Clipboard automations whose regex matches the copied text (large blobs are skipped).
function clipboardMatches(list, text) {
    var s = String(text || "");
    if (s.length === 0 || s.length > 20000)
        return [];
    var out = [];
    var items = active(list, "clipboard");
    for (var i = 0; i < items.length; i++) {
        var re = _regex(items[i].trigger.pattern);
        if (re && re.test(s))
            out.push(items[i]);
    }
    return out;
}

function validPattern(pattern) {
    return pattern === "" || _regex(pattern) !== null;
}

// Transfers that became "done" between two snapshots ([{id, state, kind, title}]).
function completedTransfers(previous, current) {
    var before = {};
    for (var i = 0; i < (previous || []).length; i++)
        before[previous[i].id] = previous[i].state;
    var out = [];
    for (var j = 0; j < (current || []).length; j++) {
        var t = current[j];
        if (t.state === "done" && before[t.id] !== undefined && before[t.id] !== "done")
            out.push(t);
    }
    return out;
}

function transferMatches(automation, transfer) {
    var kinds = automation.trigger.kinds || [];
    return kinds.length === 0 || kinds.indexOf(transfer.kind) >= 0;
}

// Login automations run once per calendar day.
function loginDue(lastRunDate, now) {
    var d = now || new Date();
    var today = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    return { due: lastRunDate !== today, today: today };
}
