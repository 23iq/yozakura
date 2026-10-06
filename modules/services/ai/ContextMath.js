.pragma library

// Context window arithmetic for the composer strip and compaction: how full
// the window is, its colour level, compact labels ("62k/200k"), the window
// of a model and the Ollama num_ctx to request.

function fraction(used, window) {
    if (!(window > 0) || !(used > 0))
        return 0;
    return Math.min(1, used / window);
}

// "ok" | "warn" | "critical"; thresholds in percent (80, 95).
function level(frac, warnAt, criticalAt) {
    var pct = frac * 100;
    if (pct >= (criticalAt || 95))
        return "critical";
    if (pct >= (warnAt || 80))
        return "warn";
    return "ok";
}

function _trim(x) {
    return String(x).replace(/\.0+$/, "").replace(/(\.\d*?)0+$/, "$1");
}

// Compact token count: 950, 1.2k, 62k, 200k, 1M, 1.05M. Binary sizes
// (context lengths like 32768) read as people say them: 32k, 128k.
function short(n) {
    n = Math.max(0, Math.round(n || 0));
    if (n >= 4096 && n < 1000000 && n % 1024 === 0)
        return (n / 1024) + "k";
    if (n >= 1000000)
        return _trim((n / 1048576 >= 0.995 && n % 1048576 === 0 ? n / 1048576 : n / 1000000).toFixed(2)) + "M";
    if (n >= 10000)
        return Math.round(n / 1000) + "k";
    if (n >= 1000)
        return _trim((n / 1000).toFixed(1)) + "k";
    return String(n);
}

function label(used, window) {
    return short(used) + "/" + short(window);
}

// Context to allocate on Ollama: the model maximum capped by the setting
// (0 = no cap); 0 when nothing is known (Ollama's default applies).
function numCtx(contextLength, setting) {
    var len = contextLength > 0 ? contextLength : 0;
    var cap = setting > 0 ? setting : 0;
    if (len && cap)
        return Math.min(len, cap);
    return cap || len;
}

function _override(entry, overrides) {
    var ids = [String(entry.id || "").toLowerCase(), String(entry.model || "").toLowerCase()];
    for (var i = 0; i < (overrides || []).length; i++) {
        var o = overrides[i] || {};
        var m = String(o.model || "").trim().toLowerCase();
        if (m && o.contextWindow > 0 && ids.indexOf(m) >= 0)
            return o.contextWindow;
    }
    return 0;
}

// Window of a catalog entry: {window, source: override|ollama|table|""}.
// Ollama gets what we allocate with num_ctx, not the model maximum.
function windowFor(entry, overrides, numCtxSetting) {
    if (!entry)
        return { window: 0, source: "" };
    var o = _override(entry, overrides);
    if (o)
        return { window: o, source: "override" };
    var info = entry.info || {};
    if (entry.provider === "ollama") {
        var n = numCtx(info.contextWindow, numCtxSetting);
        return { window: n, source: n ? "ollama" : "" };
    }
    return info.contextWindow > 0 ? { window: info.contextWindow, source: "table" } : { window: 0, source: "" };
}

// Tokens of the conversation after a turn: its prompt plus the answer.
function usedFromUsage(usage) {
    if (!usage)
        return 0;
    return (usage.inputTokens || 0) + (usage.outputTokens || 0);
}

// Rough token count of canonical messages (~4 characters per token), a
// floor when a provider under-reports (Ollama counts only uncached tokens).
function estimateTokens(messages, system) {
    var chars = String(system || "").length;
    for (var i = 0; i < (messages || []).length; i++) {
        var m = messages[i] || {};
        chars += String(m.content || "").length + String(m.thinking || "").length;
        var calls = m.toolCalls || [];
        for (var j = 0; j < calls.length; j++)
            chars += JSON.stringify(calls[j].args || {}).length + String(calls[j].name || "").length;
        var atts = m.attachments || [];
        for (var k = 0; k < atts.length; k++)
            chars += String(atts[k].text || "").length;
    }
    return Math.ceil(chars / 4);
}
