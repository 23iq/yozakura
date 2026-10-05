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

// Human summary for a permission card / tool card title.
function summarize(name, args) {
    var a = args || {};
    var keys = ["command", "path", "file_path", "url", "query", "key", "name", "panel", "workspace", "action", "text", "summary"];
    for (var i = 0; i < keys.length; i++) {
        var v = a[keys[i]];
        if (v !== undefined && v !== null && String(v).length > 0) {
            var s = String(v).replace(/\s+/g, " ");
            return name + " · " + (s.length > 60 ? s.substring(0, 59) + "…" : s);
        }
    }
    return name;
}
