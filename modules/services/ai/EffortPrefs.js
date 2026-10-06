.pragma library
.import "Effort.js" as Effort

// Which effort level a model runs with. Levels are remembered per model in
// a map {memoryKey: level}: HTTP models by catalog id ("openai:gpt-5"), CLI
// agents by agent + native model ("agent:codex/gpt-5.5", "/default" for the
// agent's default model). Agents keep their native values (their catalog's
// `efforts`, e.g. Codex "xhigh"); HTTP models use the unified levels of
// Effort.js. "auto" (stored, or the ai.effort.defaultLevel setting) means
// "send nothing": the provider's own default applies (e.g. no extended
// thinking on Anthropic). Pure functions; the state lives in
// services/ai/EffortState.qml.

function memoryKey(entry, agentModel) {
    if (!entry)
        return "";
    if (entry.kind === "agent")
        return "agent:" + entry.agent + "/" + (agentModel || "default");
    return entry.id;
}

// Unified levels an HTTP model accepts ([] hides the control).
function httpLevels(entry) {
    return entry && entry.kind !== "agent" ? Effort.levelsFor(entry.info) : [];
}

// Level an HTTP model runs with ("" = auto, send nothing): the remembered
// one, else the setting, resolved to the closest level the model supports.
function httpLevel(entry, memory, setting) {
    if (httpLevels(entry).length === 0)
        return "";
    var want = (memory || {})[memoryKey(entry)] || setting || "auto";
    return want === "auto" ? "" : Effort.resolve(want, entry.info);
}

// Catalog model of an agent (agents.models result) for `model` ("" = the
// agent's default model).
function agentModel(catalog, model) {
    var list = (catalog && catalog.models) || [];
    for (var i = 0; i < list.length; i++)
        if (model ? list[i].id === model : list[i].isDefault === true)
            return list[i];
    return null;
}

function agentLevels(catalog, model) {
    var m = agentModel(catalog, model);
    return m && m.efforts ? m.efforts.slice() : [];
}

// The agent's default level for a model (shown for "auto").
function agentDefault(catalog, model) {
    var m = agentModel(catalog, model);
    return m ? m.defaultEffort || "" : "";
}

// Remembered native level of an agent model: null = never chosen, "" = auto.
function remembered(memory, agent, model) {
    var v = (memory || {})["agent:" + agent + "/" + (model || "default")];
    if (!v)
        return null;
    return v === "auto" ? "" : v;
}

// A copy of `memory` with `level` ("" = auto) stored for `key`.
function remember(memory, key, level) {
    var out = {};
    for (var k in memory || {})
        out[k] = memory[k];
    if (key)
        out[key] = level || "auto";
    return out;
}
