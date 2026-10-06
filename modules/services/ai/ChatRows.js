.pragma library
.import "Compaction.js" as Compaction

// Conversions between ChatSession rows (ListModel rows; attachments and
// toolCalls as JSON strings), the canonical provider messages and the
// stored chat file (v2 object, v1 legacy array).

function parse(s, fallback) {
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

var FINISHED = { done: 1, denied: 1, error: 1 };

// Provider conversation: assistant rows expand their finished tool calls
// into tool result messages; notices and errors are UI-only. After a
// compaction only the last summary and the rows after it are sent.
function toMessages(rows) {
    var out = [];
    var from = Compaction.lastSummary(rows);
    if (from >= 0)
        out.push(Compaction.summaryMessage(rows[from].content));
    for (var i = from + 1; i < rows.length; i++) {
        var r = rows[i];
        if (r.role === "user") {
            out.push({ role: "user", content: r.content, attachments: parse(r.attachments, []) });
        } else if (r.role === "assistant") {
            var done = parse(r.toolCalls, []).filter(function (c) {
                return FINISHED[c.status];
            });
            if (!r.content && done.length === 0)
                continue;
            out.push({ role: "assistant", content: r.content, thinking: r.thinking || "", signature: r.signature || "", toolCalls: done.map(function (c) {
                    return { id: c.id, name: c.name, args: c.args };
                }) });
            for (var j = 0; j < done.length; j++)
                out.push({ role: "tool", toolCallId: done[j].id, name: done[j].name, content: done[j].result || "", isError: !!done[j].isError });
        }
    }
    return out;
}

// Messages for the chat file; very large inline images are dropped.
function toStored(rows) {
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        if (r.role === "error")
            continue;
        out.push({
            role: r.role, content: r.content, thinking: r.thinking || undefined, signature: r.signature || undefined, model: r.model || undefined,
            attachments: parse(r.attachments, []).map(function (a) {
                return a.base64 && a.base64.length > 400000 ? Object.assign({}, a, { base64: "" }) : a;
            }),
            toolCalls: parse(r.toolCalls, []), ts: r.ts
        });
    }
    return out;
}

// Rows (with arrays, not strings) from a chat file. v1 files are arrays
// whose assistant.functionCall is answered by a following role "function".
function fromStored(data) {
    var msgs = Array.isArray(data) ? data : ((data && data.messages) || []);
    var rows = [];
    for (var i = 0; i < msgs.length; i++) {
        var m = msgs[i];
        if (m.role === "function") {
            for (var j = rows.length - 1; j >= 0; j--) {
                var calls = rows[j].toolCalls || [];
                if (rows[j].role === "assistant" && calls.length > 0) {
                    calls[calls.length - 1].result = m.content;
                    calls[calls.length - 1].status = "done";
                    break;
                }
            }
            continue;
        }
        var row = { role: m.role === "system" ? "notice" : m.role, content: m.content || "", thinking: m.thinking || "", signature: m.signature || "", model: m.model || "", attachments: m.attachments || [], toolCalls: m.toolCalls || [], ts: m.ts || 0 };
        if (m.functionCall)
            row.toolCalls = [{ id: "legacy_" + i, name: m.functionCall.name, args: m.functionCall.args, title: m.functionCall.name, status: m.functionApproved === false ? "denied" : "done" }];
        rows.push(row);
    }
    return rows;
}
