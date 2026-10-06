.pragma library

// Permission policy for tool calls made by chat models (API/local models with
// MCP tools). CLI agents use the same rules in the Go agents service.
// Default: "safe auto, ask the rest" — read-only tools run immediately,
// everything else shows a permission card (Allow / Allow for session / Deny).

// Yozakura tools that read private data (clipboard, notifications): they
// are read-only but always ask, like in the Go agents policy.
var PRIVATE = { clipboard_read: true, clipboard_history: true, notifications_list: true };

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

// policy: {yolo, autoApprove: ["read"], sessionRules: {key: true}}
// returns "allow" | "ask"
function decide(tool, policy) {
    var p = policy || {};
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
