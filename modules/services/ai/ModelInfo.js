.pragma library
.import "ContextMath.js" as ContextMath

// Capability records of chat models: lookups in the bundled table
// (assets/ai/models.json, same rules as the backend's ModelTable.Lookup),
// records from an Ollama probe, and the badges the model picker shows.
// Record fields (all optional, missing = unknown): contextWindow, maxOutput,
// vision, tools, reasoning, efforts, effortMap, budget, capabilities, family.

function _longest(entries, id) {
    var best = null;
    for (var i = 0; i < (entries || []).length; i++) {
        var p = String(entries[i].prefix || "").toLowerCase();
        if (p && id.indexOf(p) === 0 && (!best || p.length > best.prefix.length))
            best = entries[i];
    }
    return best;
}

// The table entry for provider/model: longest matching prefix in the
// provider's table, then the vendor table of "vendor/model" ids, then the
// shared "open" table; each with the full id first, then without "vendor/".
function lookup(table, providerId, model) {
    if (!table || !table.providers || !model)
        return null;
    var id = String(model).trim().toLowerCase().replace(/:free$/, "");
    var ids = [id];
    var tables = [providerId];
    var slash = id.indexOf("/");
    if (slash > 0) {
        ids.push(id.substring(slash + 1));
        var target = (table.vendors || {})[id.substring(0, slash)];
        if (target)
            tables.push(target);
    }
    tables.push("open");
    for (var t = 0; t < tables.length; t++)
        for (var c = 0; c < ids.length; c++) {
            var e = _longest(table.providers[tables[t]], ids[c]);
            if (e)
                return e;
        }
    return null;
}

// Record of one model of a providers.ollama.probe result.
function fromOllama(m) {
    var caps = (m && m.capabilities) || [];
    var detailed = !!(m && m.detailed);
    var info = { id: m ? m.id : "", family: (m && m.family) || "", capabilities: caps, contextWindow: (m && m.contextLength) || 0, source: "ollama" };
    // Without /api/show details the capabilities are unknown, not absent.
    if (detailed) {
        info.tools = caps.indexOf("tools") >= 0;
        info.vision = caps.indexOf("vision") >= 0;
        info.reasoning = caps.indexOf("thinking") >= 0 ? "ollama_think" : "none";
    }
    return info;
}

// Badges for the picker: [{kind: tools|chatOnly|vision|thinking|context, text}].
// `text` is only set for context (e.g. "200k"); the others are translated by the view.
function badges(info) {
    var out = [];
    if (!info)
        return out;
    if (info.tools === true)
        out.push({ kind: "tools", text: "" });
    else if (info.tools === false)
        out.push({ kind: "chatOnly", text: "" });
    if (info.vision === true)
        out.push({ kind: "vision", text: "" });
    if (info.reasoning && info.reasoning !== "none")
        out.push({ kind: "thinking", text: "" });
    if (info.contextWindow > 0)
        out.push({ kind: "context", text: ContextMath.short(info.contextWindow) });
    return out;
}
