.pragma library

// One transcript for every engine. Normalises ChatSession rows (HTTP chat,
// see services/ai/ChatSession.qml) and AgentTimeline blocks (CLI agents, see
// services/ai/AgentTimeline.js) into flat, ListModel-friendly rows:
//
//   {kind: user|assistant|thinking|action|permission|diff|error|notice,
//    key, text, engine (model name), status, streaming, attachments (JSON), title, tool,
//    category, input (JSON string), output, isError, path, diff, decision,
//    options (JSON), undo (JSON string, "" = not undoable), ref, source, ts}
//
// `source` is the index of the originating row/block (retry, permission
// answers), `ref` the tool call / permission request id. `undo` is filled by
// tools that can be reverted ({server, tool, args, label}); ActionRow shows
// an Undo button for it.
//
// patch() turns two row lists into minimal ListModel operations, so a
// streamed token updates one row only.

var KINDS = ["user", "assistant", "thinking", "action", "permission", "diff", "error", "notice"];

var FIELDS = {
    kind: "", key: "", text: "", engine: "", status: "", streaming: false, attachments: "[]",
    title: "", tool: "", category: "", input: "", output: "", isError: false, path: "", diff: "",
    decision: "", options: "", undo: "", ref: "", source: 0, ts: 0
};

function _json(v, empty) {
    if (v === undefined || v === null || v === "")
        return empty;
    if (typeof v === "string")
        return v;
    try {
        return JSON.stringify(v);
    } catch (e) {
        return empty;
    }
}

function _parse(s, fallback) {
    if (!s)
        return fallback;
    if (typeof s !== "string")
        return s;
    try {
        return JSON.parse(s);
    } catch (e) {
        return fallback;
    }
}

function row(kind, fields) {
    var r = {};
    for (var k in FIELDS)
        r[k] = FIELDS[k];
    r.kind = kind;
    for (var f in fields)
        if (FIELDS.hasOwnProperty(f) && fields[f] !== undefined && fields[f] !== null)
            r[f] = fields[f];
    return r;
}

function _opts(o) {
    return {
        showThinking: !o || o.showThinking !== false
    };
}

// Rows of one ChatSession row (index = its position in session.rows).
function fromChatRow(r, index, options) {
    var o = _opts(options);
    if (!r)
        return [];
    var base = "c" + index;
    var ts = r.ts || 0;
    var streaming = r.status === "streaming";
    switch (r.role) {
    case "user":
        return [row("user", { key: base, text: r.content || "", attachments: _json(r.attachments, "[]"), source: index, ts: ts })];
    case "assistant": {
        var out = [];
        if (o.showThinking && r.thinking)
            out.push(row("thinking", { key: base + ":think", text: r.thinking, streaming: streaming && !r.content, source: index, ts: ts }));
        var calls = _parse(r.toolCalls, []);
        // An empty streaming answer still gets a row: it carries the spinner.
        if (r.content || (streaming && !r.thinking && calls.length === 0))
            out.push(row("assistant", { key: base + ":text", text: r.content || "", engine: r.model || "", streaming: streaming, source: index, ts: ts }));
        for (var i = 0; i < calls.length; i++) {
            var c = calls[i] || {};
            var common = {
                key: base + ":" + (c.id || i), ref: c.id || "", tool: c.tool || c.name || "", title: c.title || c.name || "",
                category: c.category || "mcp", input: _json(c.args, ""), source: index, ts: ts
            };
            if (c.status === "ask") {
                common.status = "pending";
                common.options = _json(["allow", "allow_session", "deny"], "");
                out.push(row("permission", common));
            } else {
                common.status = c.status || "running";
                common.output = c.result || "";
                common.isError = !!c.isError;
                common.decision = c.decision || "";
                common.undo = _json(c.undo, "");
                out.push(row("action", common));
            }
        }
        return out;
    }
    case "error":
        return [row("error", { key: base, text: r.content || "", source: index, ts: ts })];
    default:
        return [row("notice", { key: base, text: r.content || "", source: index, ts: ts })];
    }
}

// Rows of one AgentTimeline block (index = its position in the timeline).
function fromBlock(b, index, options) {
    var o = _opts(options);
    if (!b)
        return [];
    var base = "a" + index;
    var ts = b.ts || 0;
    switch (b.type) {
    case "user":
        return [row("user", { key: base, text: b.text || "", source: index, ts: ts })];
    case "assistant":
        return [row("assistant", { key: base, text: b.text || "", streaming: b.status === "streaming", source: index, ts: ts })];
    case "thinking":
        return o.showThinking ? [row("thinking", { key: base, text: b.text || "", streaming: b.status === "streaming", source: index, ts: ts })] : [];
    case "tool":
        // While its permission card waits, the card stands in for the row.
        if (b.status === "ask")
            return [];
        return [row("action", {
            key: base, ref: (b.key || "").replace(/^tool:/, ""), tool: b.tool || "", title: b.title || b.tool || "",
            category: b.category || "other", status: b.status || "running", input: b.input || "", output: b.output || "",
            isError: !!b.isError, path: b.path || "", diff: b.diff || "", decision: b.decision || "", undo: _json(b.undo, ""),
            source: index, ts: ts
        })];
    case "permission":
        // Answered cards fold back into their tool row.
        if (b.linked && b.status !== "pending")
            return [];
        return [row("permission", {
            key: base, ref: (b.key || "").replace(/^perm:/, ""), tool: b.tool || "", title: b.title || b.tool || "",
            category: b.category || "other", status: b.status || "pending", input: b.input || "", path: b.path || "",
            diff: b.diff || "", decision: b.decision || "", options: b.options || "", source: index, ts: ts
        })];
    case "diff":
        return [row("diff", { key: base, title: b.path || "", path: b.path || "", diff: b.diff || "", category: "write", status: "done", source: index, ts: ts })];
    case "error":
        return [row("error", { key: base, text: b.text || "", source: index, ts: ts })];
    default:
        return [row("notice", { key: base, text: b.text || "", source: index, ts: ts })];
    }
}

function normalize(kind, item, index, options) {
    return kind === "agent" ? fromBlock(item, index, options) : fromChatRow(item, index, options);
}

// Every row of a whole source list (tests, rebuilds).
function build(kind, items, options) {
    var out = [];
    for (var i = 0; i < items.length; i++)
        out = out.concat(normalize(kind, items[i], i, options));
    return out;
}

function changedFields(a, b) {
    var out = null;
    for (var k in FIELDS) {
        if (a[k] !== b[k]) {
            out = out || {};
            out[k] = b[k];
        }
    }
    return out;
}

// ListModel operations turning `before` into `after` (both row lists of the
// same source item), relative to `offset` in the flat model:
//   {op: "set", index, fields} | {op: "insert", index, row} | {op: "remove", index, count}
function patch(before, after, offset) {
    var ops = [];
    var base = offset || 0;
    var n = Math.min(before.length, after.length);
    for (var i = 0; i < n; i++) {
        var fields = changedFields(before[i], after[i]);
        if (fields)
            ops.push({ op: "set", index: base + i, fields: fields });
    }
    for (var j = n; j < after.length; j++)
        ops.push({ op: "insert", index: base + j, row: after[j] });
    if (before.length > after.length)
        ops.push({ op: "remove", index: base + after.length, count: before.length - after.length });
    return ops;
}

// True when a row starts a new speaker group (assistant header, spacing).
function startsGroup(prevKind, kind) {
    if (kind === "user" || kind === "notice" || kind === "error")
        return true;
    return !prevKind || prevKind === "user" || prevKind === "notice" || prevKind === "error";
}

// Parsed undo descriptor of a row, or null.
function undoOf(r) {
    var u = _parse(r && r.undo, null);
    return u && typeof u === "object" && u.tool ? u : null;
}

// One-line summary of a tool input ("$ make check", a path, or compact JSON).
function inputSummary(input) {
    var o = _parse(input, null);
    if (!o || typeof o !== "object")
        return input ? String(input) : "";
    if (o.command)
        return "$ " + o.command;
    if (o.file_path || o.path)
        return o.file_path || o.path;
    var s = JSON.stringify(o);
    return s === "{}" ? "" : s;
}
