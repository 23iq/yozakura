.pragma library

// Splits assistant markdown into render segments:
//   {type: "text", content}
//   {type: "code", language, content, open}   (open = fence not closed yet, i.e. streaming)
//   {type: "thinking", content, open}         (<think>…</think> emitted inline by local models)
// Everything else is left to Text.MarkdownText.

var FENCE = /^ {0,3}(`{3,}|~{3,})\s*([^`\s]*)[^`]*$/;

function _pushText(out, lines) {
    var text = lines.join("\n");
    if (text.trim().length > 0)
        out.push({ type: "text", content: text.replace(/^\n+|\n+$/g, "") });
}

function _splitThinking(text) {
    // Returns [{type: "text"|"thinking", content, open}] for <think> blocks.
    var parts = [];
    var rest = text;
    while (rest.length > 0) {
        var start = rest.indexOf("<think>");
        if (start < 0) {
            parts.push({ type: "text", content: rest });
            break;
        }
        if (start > 0)
            parts.push({ type: "text", content: rest.substring(0, start) });
        var end = rest.indexOf("</think>", start + 7);
        if (end < 0) {
            parts.push({ type: "thinking", content: rest.substring(start + 7).trim(), open: true });
            break;
        }
        parts.push({ type: "thinking", content: rest.substring(start + 7, end).trim(), open: false });
        rest = rest.substring(end + 8);
    }
    return parts;
}

function _splitFences(text, out) {
    var lines = text.split("\n");
    var buffer = [];
    var code = null;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (code === null) {
            var m = FENCE.exec(line);
            if (m) {
                _pushText(out, buffer);
                buffer = [];
                code = { fence: m[1], language: (m[2] || "").toLowerCase(), lines: [] };
            } else {
                buffer.push(line);
            }
        } else {
            var trimmed = line.trim();
            if (trimmed.length >= code.fence.length && trimmed.charAt(0) === code.fence.charAt(0) && trimmed === new Array(trimmed.length + 1).join(code.fence.charAt(0))) {
                out.push({ type: "code", language: code.language, content: code.lines.join("\n"), open: false });
                code = null;
            } else {
                code.lines.push(line);
            }
        }
    }
    if (code !== null)
        out.push({ type: "code", language: code.language, content: code.lines.join("\n"), open: true });
    else
        _pushText(out, buffer);
}

function segments(text) {
    var out = [];
    if (!text)
        return out;
    var parts = _splitThinking(String(text));
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].type === "thinking") {
            if (parts[i].content.length > 0 || parts[i].open)
                out.push(parts[i]);
        } else {
            _splitFences(parts[i].content, out);
        }
    }
    return out;
}

// Plain text without markdown decoration, for previews and copy-as-text.
function plain(text) {
    if (!text)
        return "";
    return String(text)
        .replace(/<think>[\s\S]*?(<\/think>|$)/g, "")
        .replace(/```[^\n]*\n?/g, "")
        .replace(/`([^`]*)`/g, "$1")
        .replace(/\*\*([^*]+)\*\*/g, "$1")
        .replace(/__([^_]+)__/g, "$1")
        .replace(/^#{1,6}\s+/gm, "")
        .replace(/^\s*[-*+]\s+/gm, "• ")
        .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
        .trim();
}

// One-line preview (session lists, notifications).
function preview(text, max) {
    var limit = max || 80;
    var p = plain(text).replace(/\s+/g, " ");
    if (p.length <= limit)
        return p;
    return p.substring(0, limit - 1).replace(/\s+\S*$/, "") + "…";
}

function escapeHtml(text) {
    return String(text === undefined || text === null ? "" : text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}
