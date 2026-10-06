.pragma library

// Child rows of a CLI agent in the model picker (pure, node-tested): the
// agent's own models from its `agents.models` catalog
// ({models: [{id, name, efforts, defaultEffort, isDefault, resolved}],
// manualModel, loading, error}), a loading/error/empty status row and a
// manual model entry. Used by PickerModel.build.
// Rows:
//   {type: "agentModel", key, group, entry, model, current}
//   {type: "agentStatus", key, group, entry, status: loading|error|empty, error}
//   {type: "agentManual", key, group, entry}

function words(q) {
    return String(q || "").toLowerCase().split(/\s+/).filter(function (w) {
        return w.length > 0;
    });
}

function matches(ws, hay) {
    for (var i = 0; i < ws.length; i++)
        if (hay.indexOf(ws[i]) < 0)
            return false;
    return true;
}

// An agent that can be expanded into its models (installed and enabled).
function expandable(entry) {
    return !!entry && entry.kind === "agent" && entry.available !== false && !!entry.agent;
}

function agentHay(entry) {
    return [entry.name, entry.agent, entry.id, entry.description || ""].join(" ").toLowerCase();
}

function modelHay(m) {
    return [m.name, m.id, m.resolved || "", (m.efforts || []).join(" ")].join(" ").toLowerCase();
}

// Whether a child model of `entry` matches every word of the query.
function childMatches(entry, catalog, ws) {
    if (!expandable(entry) || !catalog || ws.length === 0)
        return false;
    var base = agentHay(entry);
    var list = catalog.models || [];
    for (var i = 0; i < list.length; i++)
        if (list[i] && matches(ws, base + " " + modelHay(list[i])))
            return true;
    return false;
}

// Whether a catalog model is the one the visible engine runs with
// (`currentModel` "" = the agent's default model).
function isCurrent(entry, m, o) {
    if (!o || entry.id !== o.currentId)
        return false;
    return o.currentAgentModel ? m.id === o.currentAgentModel : m.isDefault === true;
}

// Rows under `entry`: all of them when expanded, the matching models while
// searching (status/manual rows only when the agent itself matches).
function children(entry, catalog, o) {
    var opts = o || {};
    if (!expandable(entry))
        return [];
    var ws = words(opts.query);
    var searching = ws.length > 0;
    var open = !!(opts.expanded || {})[entry.agent];
    if (!searching && !open)
        return [];
    var group = opts.group || "agent";
    var agentHit = matches(ws, agentHay(entry));
    var rows = [];
    var c = catalog || null;
    var list = c ? (c.models || []) : [];
    var base = agentHay(entry);
    for (var i = 0; i < list.length; i++) {
        var m = list[i];
        if (!m || (searching && !matches(ws, base + " " + modelHay(m))))
            continue;
        rows.push({ type: "agentModel", key: "am:" + entry.agent + ":" + m.id, group: group, entry: entry, model: m, current: isCurrent(entry, m, opts) });
    }
    if (searching && !agentHit)
        return rows;
    var status = "";
    if (!c || (c.loading && list.length === 0))
        status = "loading";
    else if (c.error)
        status = "error";
    else if (list.length === 0 && !c.manualModel)
        status = "empty";
    if (status)
        rows.push({ type: "agentStatus", key: "as:" + entry.agent, group: group, entry: entry, status: status, error: c ? c.error || "" : "" });
    if (c && c.manualModel)
        rows.push({ type: "agentManual", key: "amm:" + entry.agent, group: group, entry: entry });
    return rows;
}

// Native model id to launch for a picked catalog model: "" for an alias of
// the agent's own default (Claude's "default"; the CLI resolves it), else
// its id, so an explicit pick stays even when the agent's default changes.
function nativeId(m) {
    return !m || (m.isDefault === true && m.id === "default") ? "" : String(m.id || "");
}
