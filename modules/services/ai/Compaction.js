.pragma library

// Compaction of HTTP chats: older turns are summarised into one `summary`
// row; requests then send that summary plus the rows after it. Pure
// functions over ChatSession rows ({role, content, thinking, toolCalls}).

var PROMPT = "You compact a conversation between a user and an AI assistant so it can continue in a smaller context. " +
    "Write a concise summary in the conversation's language that keeps everything needed to go on: the user's goals and preferences, " +
    "decisions and facts established, results of tool calls (files, settings, values), open questions and the current task. " +
    "Use short bullet points, no preamble.";

var SUMMARY_PREFIX = "Summary of the earlier conversation (older messages were compacted):\n\n";

// Index of the last summary row, or -1.
function lastSummary(rows) {
    for (var i = (rows || []).length - 1; i >= 0; i--)
        if (rows[i] && rows[i].role === "summary")
            return i;
    return -1;
}

// What to compact so that the last `keepTurns` user turns stay verbatim:
// {start, cut, previous} (rows [start, cut) are summarised together with the
// previous summary row `previous`, -1 if none; the new summary goes at
// `cut`), or null when there is nothing older to compact.
function plan(rows, keepTurns) {
    var list = rows || [];
    var previous = lastSummary(list);
    var start = previous + 1;
    var users = [];
    for (var i = start; i < list.length; i++)
        if (list[i] && list[i].role === "user")
            users.push(i);
    var keep = Math.max(0, Math.floor(keepTurns || 0));
    if (users.length <= keep)
        return null;
    var cut = keep === 0 ? list.length : users[users.length - keep];
    // Something must be summarised besides the old summary itself.
    var content = false;
    for (var j = start; j < cut; j++)
        if (list[j] && (list[j].role === "user" || list[j].role === "assistant"))
            content = true;
    return content ? { start: start, cut: cut, previous: previous } : null;
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

function _clip(text, max) {
    var t = String(text || "");
    return t.length > max ? t.substring(0, max) + " …" : t;
}

// Plain-text transcript of the planned rows for the summarising model.
function transcript(rows, p) {
    var out = [];
    if (p.previous >= 0)
        out.push("Earlier summary:\n" + rows[p.previous].content);
    for (var i = p.start; i < p.cut; i++) {
        var r = rows[i];
        if (r.role === "user") {
            out.push("User: " + (r.content || ""));
        } else if (r.role === "assistant") {
            if (r.content)
                out.push("Assistant: " + r.content);
            var calls = _parse(r.toolCalls, []);
            for (var c = 0; c < calls.length; c++)
                out.push("Tool " + (calls[c].tool || calls[c].name) + " " + _clip(JSON.stringify(calls[c].args || {}), 300) + " -> " + _clip(calls[c].result, 1500));
        }
    }
    return out.join("\n\n");
}

// Request messages for the summarising model.
function request(rows, p) {
    return [{ role: "user", content: "Summarise this conversation:\n\n" + transcript(rows, p) }];
}

// Canonical message that stands in for the compacted rows.
function summaryMessage(text) {
    return { role: "user", content: SUMMARY_PREFIX + String(text || "") };
}

// Whether sending should compact first: auto-compaction on, the window
// known and at least `atPercent` full, and something to compact.
function shouldAutoCompact(enabled, frac, atPercent) {
    return !!enabled && frac > 0 && frac * 100 >= (atPercent || 95);
}
