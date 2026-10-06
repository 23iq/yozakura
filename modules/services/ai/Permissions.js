.pragma library

// Permission policy for tool calls made by chat models (API/local models with
// MCP tools). CLI agents use the same rules in the Go agents service.
// Default: "safe auto, ask the rest" — read-only tools run immediately,
// everything else shows a permission card (Allow / Allow for session / Deny).

// Yozakura tools that read private data (clipboard, notifications): they
// are read-only but always ask, like in the Go agents policy.
var PRIVATE = { clipboard_read: true, clipboard_history: true, notifications_list: true, screen_look: true };

// Yozakura tools that always ask, even with "allow for this session", a
// permissive policy or YOLO. MUST contain every entry of routines.ConfirmTools
// in Go (backend/pkg/svc/routines/confirm.go; tests/ai-confirm-tools.test.cjs
// enforces it): they rewrite the user's keybinds, close windows, delete
// routines and notes or install software.
// Their card has no "for session" choice.
var CONFIRM = { binds_set: true, binds_remove: true, app_close: true, routine_delete: true, notes_delete: true, extras_install: true };

// Routine steps as sensitive as a confirm tool (routines/confirm.go): an
// arbitrary command line, a raw dispatcher, closing the focused window and
// quitting the shell (<app>.quit).
var CONFIRM_ACTIONS = { "command.run": true, "legacy.dispatcher": true, "window.close": true };
var ROUTINE_ACTION = "utilities.routine";
var ROUTINE_TOOLS = { routine_run: true, routine_save: true, routine_delete: true, routines_list: true };

function _findRoutine(routines, ref) {
    var r = String(ref || "");
    for (var i = 0; i < routines.length; i++)
        if (routines[i] && routines[i].id === r)
            return routines[i];
    for (var j = 0; j < routines.length; j++)
        if (routines[j] && String(routines[j].name || "").toLowerCase() === r.toLowerCase())
            return routines[j];
    return null;
}

// What in `steps` needs the user's confirmation before an AI saves or runs
// it (nested routines through `routines`; unknown ones count).
function routineConfirmSteps(steps, routines, depth, visited) {
    var out = [];
    var seen = visited || {};
    var list = Array.isArray(routines) ? routines : [];
    (Array.isArray(steps) ? steps : []).forEach(function (s) {
        if (!s)
            return;
        var tool = String(s.tool || "").trim();
        var action = String(s.action || "").trim();
        if (s.kind === "tool" && (CONFIRM[tool] || ROUTINE_TOOLS[tool]))
            out.push(tool);
        if (s.kind !== "action")
            return;
        if (CONFIRM_ACTIONS[action] || /\.quit$/.test(action))
            out.push(action);
        if (action !== ROUTINE_ACTION)
            return;
        var ref = String((s.args && s.args.routine) || "").trim();
        var sub = (depth || 0) < 3 ? _findRoutine(list, ref) : null;
        if (!sub) {
            out.push("routine " + ref);
        } else if (!seen[sub.id]) {
            seen[sub.id] = true;
            out = out.concat(routineConfirmSteps(sub.steps, list, (depth || 0) + 1, seen));
        }
    });
    return out;
}

// tool: {name, server}; args: the call's arguments; routines: the saved
// routines (RoutinesService.routines). Saving or running a routine that
// closes windows, edits keybinds or runs a command line asks too; a run of
// a routine the shell does not know asks.
function mustConfirm(tool, args, routines) {
    if (!tool || tool.server !== "yozakura")
        return false;
    var name = String(tool.name || "");
    if (CONFIRM[name] === true)
        return true;
    var a = args || {};
    if (name === "routine_save")
        return routineConfirmSteps(a.steps, routines).length > 0;
    if (name === "routine_run") {
        var r = _findRoutine(Array.isArray(routines) ? routines : [], a.id);
        if (!r)
            return true;
        var visited = {};
        visited[r.id] = true;
        return routineConfirmSteps(r.steps, routines, 0, visited).length > 0;
    }
    return false;
}

// The backend runs an AI's routine_run of such a routine only after the
// user allowed it: the shell grants that one run (routines.grant {id}).
function needsGrant(tool) {
    return !!tool && tool.server === "yozakura" && tool.name === "routine_run";
}

var READ_VERBS = /^(get|list|read|search|find|query|show|describe|status|fetch_status|schema|view|lookup|count)([_\-.]|$)/;

// tool: {name, server, readOnly, annotations}
// Third-party MCP tools are reads only when the server declares
// readOnlyHint: names like "query" or "delete_history" prove nothing. The
// name heuristic only picks the category of a tool that will ask anyway,
// and decides reads for Yozakura's own server.
function category(tool) {
    if (!tool)
        return "other";
    var ann = tool.annotations || {};
    if (tool.server === "yozakura" && PRIVATE[String(tool.name || "")])
        return "mcp";
    if (tool.readOnly === true || ann.readOnlyHint === true)
        return "read";
    if (ann.openWorldHint === true)
        return "network";
    var name = String(tool.name || "").toLowerCase();
    if (tool.server === "yozakura" && (READ_VERBS.test(name) || /_(get|list|status|read|history|schema)$/.test(name)))
        return "read";
    if (/(shell|exec|command|run|bash)/.test(name))
        return "exec";
    if (/(fetch|http|url|web|download|browse)/.test(name))
        return "network";
    if (/(write|set|create|delete|remove|move|apply|send|update|edit|toggle|switch|focus|control)/.test(name))
        return "write";
    return "mcp";
}

function ruleKey(tool) {
    return (tool.server ? tool.server + "/" : "") + (tool.name || "");
}

// tool: {name, server, annotations, args}
// policy: {yolo, autoApprove: ["read"], sessionRules: {key: true}, routines}
// returns "allow" | "ask"
function decide(tool, policy) {
    var p = policy || {};
    if (mustConfirm(tool, tool && tool.args, p.routines))
        return "ask";
    if (p.yolo)
        return "allow";
    if (p.sessionRules && p.sessionRules[ruleKey(tool)])
        return "allow";
    var auto = p.autoApprove || ["read"];
    if (auto.indexOf(category(tool)) >= 0)
        return "allow";
    return "ask";
}

// A descriptor contains only data; callers translate it for their UI. Restrict
// known effects to our built-in server, never infer a third-party tool's effect.
function summaryDescriptor(name, args, server) {
    if (server !== "yozakura")
        return null;
    var a = args || {};
    if (name === "config_set" && a.key) {
        var key = String(a.key);
        if (a.domain)
            key = String(a.domain) + "." + key;
        return a.value !== undefined ? {
            key: "ai.permission_config_set", values: [key, valueText(a.value)]
        } : { key: "ai.permission_config_change", values: [key] };
    }
    if (name === "preset_apply" && a.name)
        return { key: "ai.permission_preset_apply", values: [String(a.name)] };
    if (name === "workspace_switch" && a.workspace !== undefined)
        return { key: "ai.permission_workspace_switch", values: [String(a.workspace)] };
    if (name === "window_focus" && (a.id || a.app || a.title))
        return { key: "ai.permission_window_focus", values: [String(a.id || a.app || a.title)] };
    if (name === "window_move_to_workspace" && a.workspace !== undefined)
        return {
            key: a.follow === true ? "ai.permission_window_follow" : "ai.permission_window_move",
            values: [a.id || a.app ? String(a.id || a.app) : null, String(a.workspace)]
        };
    return null;
}

function valueText(value) {
    return typeof value === "string" ? value : JSON.stringify(value);
}

// Unknown tools retain their actual name and arguments. Details in the card
// show the original JSON even when a known tool has a plain-language title.
function summarize(name, args, translate, server) {
    var descriptor = summaryDescriptor(name, args, server);
    if (descriptor && typeof translate === "function") {
        var values = descriptor.values.map(function (value) {
            return value === null ? translate("ai.permission_focused_window", []) : value;
        });
        return translate(descriptor.key, values);
    }
    var a = args || {};
    return Object.keys(a).length ? String(name) + " · " + JSON.stringify(a) : String(name);
}
