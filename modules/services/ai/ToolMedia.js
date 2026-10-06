.pragma library

// What a chat engine takes from an MCP tool result besides its text:
//   * the undo descriptor (Yozakura tools return "undo": {tool, args} in
//     their JSON; ActionRow shows Undo and Ai.undoAction calls it), and
//   * images (screen_look returns an MCP image block), which vision models
//     receive as a user message right after the tool results.
// Tested in tests/ai-tool-media.test.cjs.

// Undo descriptor {server, tool, args} of a successful tool result text, or null.
function undoFrom(server, text, isError) {
    if (isError || !text)
        return null;
    var t = String(text).trim();
    if (t.charAt(0) !== "{")
        return null;
    try {
        var v = JSON.parse(t);
        var u = v && v.undo;
        if (u && typeof u.tool === "string" && u.tool) {
            var d = { server: u.server || server || "yozakura", tool: u.tool, args: u.args && typeof u.args === "object" ? u.args : {} };
            if (u.label)
                d.label = String(u.label);
            return d;
        }
    } catch (e) {}
    return null;
}

// A CLI agent's name for one of our own tools: "mcp__yozakura__timer_start"
// (Claude Code), "yozakura.timer_start" / "yozakura__timer_start" (Codex,
// OpenCode).
function isYozakuraTool(name) {
    return /^(mcp__)?yozakura(__|[.:/])/.test(String(name || ""));
}

// Image blocks of an MCP content list as chat attachments.
function images(content) {
    var out = [];
    (content || []).forEach(function (c, i) {
        if (c && c.type === "image" && c.data)
            out.push({ type: "image", mimeType: c.mimeType || "image/png", base64: c.data, name: "tool-image-" + (i + 1) });
    });
    return out;
}

// The user message carrying the images of finished tool calls (byId:
// {callId: [attachments]}), or null when there are none.
function imageMessage(calls, byId) {
    if (!byId)
        return null;
    var atts = [];
    var names = [];
    (calls || []).forEach(function (c) {
        var imgs = byId[c.id];
        if (imgs && imgs.length) {
            atts = atts.concat(imgs);
            names.push(c.name || c.tool || "tool");
        }
    });
    if (!atts.length)
        return null;
    return { role: "user", content: "[Images returned by " + names.join(", ") + "]", attachments: atts };
}

// Vision support of a catalog model (provider images flag, model override).
function canSee(model, provider) {
    return !!(model && provider && provider.images && model.images !== false);
}
