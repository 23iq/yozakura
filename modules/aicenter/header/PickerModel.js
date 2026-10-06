.pragma library
.import "AgentPickerRows.js" as AgentRows

// Rows of the model picker (pure, node-tested). Input: catalog entries
// ({id, name, model, provider, kind, available, ...}) and options:
//   query            search text (every word must match name/id/provider)
//   kind             "all" | "agent" (Code) | "chat" (HTTP only)
//   recent           recently used ids, newest first
//   defaultId        the space's default engine (listed first in its group)
//   groupByProvider  group headers per provider (else one flat list)
//   showRecent       a "Recent" group on top (no query only)
//   unconnected      [{id, label, icon}] providers without a connection
//   showUnconnected  list them at the end with a Connect action
//   order            provider ids in display order (others follow by id)
//   labels           {providerId: label} for search
//   agentCatalogs    {agentId: agents.models result} (CLI agents' own models)
//   expanded         {agentId: true} agents whose models are listed
//   currentId, currentAgentModel  the visible engine and agent model
// Output: [{type: "header", key, group}
//          | {type: "model", key, group, entry, recent, expandable, expanded}
//          | agent child rows (AgentPickerRows.js: agentModel/agentStatus/agentManual)
//          | {type: "provider", key, group: "unconnected", provider}]
// A search also matches agent models ("haiku" finds Claude > Haiku).
// Header groups: "recent", "agent", a provider id, "unconnected".

var RECENT_MAX = 4;

function _words(q) {
    return String(q || "").toLowerCase().split(/\s+/).filter(function (w) {
        return w.length > 0;
    });
}

function _matches(words, hay) {
    for (var i = 0; i < words.length; i++)
        if (hay.indexOf(words[i]) < 0)
            return false;
    return true;
}

function _hay(m, labels) {
    return [m.name, m.model, m.id, m.provider, (labels || {})[m.provider] || "", m.description || ""].join(" ").toLowerCase();
}

function _kindOk(m, kind) {
    if (kind === "agent")
        return m.kind === "agent";
    if (kind === "chat")
        return m.kind !== "agent";
    return true;
}

function filter(models, o) {
    var words = _words(o.query);
    var catalogs = o.agentCatalogs || {};
    return (models || []).filter(function (m) {
        return m && _kindOk(m, o.kind || "all") && (_matches(words, _hay(m, o.labels)) || AgentRows.childMatches(m, catalogs[m.agent], words));
    });
}

// The model row of `entry` followed by its agent children, if any.
function _push(rows, entry, group, o, recent) {
    var kids = AgentRows.children(entry, (o.agentCatalogs || {})[entry.agent], {
        query: o.query,
        expanded: o.expanded,
        group: group,
        currentId: o.currentId,
        currentAgentModel: o.currentAgentModel
    });
    var searching = _words(o.query).length > 0;
    rows.push({ type: "model", key: "m:" + entry.id, group: group, entry: entry, recent: recent, expandable: AgentRows.expandable(entry),
        expanded: kids.length > 0 || (!searching && !!(o.expanded || {})[entry.agent]) });
    for (var i = 0; i < kids.length; i++)
        rows.push(kids[i]);
}

function _groupRank(group, order) {
    if (group === "agent")
        return -1;
    var i = (order || []).indexOf(group);
    return i >= 0 ? i : 1000;
}

function build(models, opts) {
    var o = opts || {};
    var list = filter(models, o);
    var rows = [];
    var recent = o.recent || [];
    var searching = _words(o.query).length > 0;
    if (o.showRecent !== false && !searching && o.groupByProvider !== false) {
        var picked = [];
        for (var r = 0; r < recent.length && picked.length < RECENT_MAX; r++) {
            var hit = list.filter(function (m) {
                return m.id === recent[r];
            })[0];
            if (hit)
                picked.push(hit);
        }
        if (picked.length > 0) {
            rows.push({ type: "header", key: "h:recent", group: "recent" });
            for (var p = 0; p < picked.length; p++)
                rows.push({ type: "model", key: "r:" + picked[p].id, group: "recent", entry: picked[p], recent: true });
        }
    }
    if (o.groupByProvider === false) {
        var flat = list.slice().sort(function (a, b) {
            var ra = recent.indexOf(a.id), rb = recent.indexOf(b.id);
            ra = ra < 0 ? 1000 : ra;
            rb = rb < 0 ? 1000 : rb;
            return ra - rb || String(a.name).localeCompare(String(b.name));
        });
        for (var f = 0; f < flat.length; f++)
            _push(rows, flat[f], "", o, recent.indexOf(flat[f].id) >= 0);
    } else {
        var groups = {};
        var names = [];
        for (var i = 0; i < list.length; i++) {
            var g = list[i].kind === "agent" ? "agent" : list[i].provider;
            if (!groups[g]) {
                groups[g] = [];
                names.push(g);
            }
            groups[g].push(list[i]);
        }
        names.sort(function (a, b) {
            return _groupRank(a, o.order) - _groupRank(b, o.order) || a.localeCompare(b);
        });
        for (var n = 0; n < names.length; n++) {
            var items = groups[names[n]].slice().sort(function (a, b) {
                return (a.id === o.defaultId ? -1 : 0) - (b.id === o.defaultId ? -1 : 0);
            });
            rows.push({ type: "header", key: "h:" + names[n], group: names[n] });
            for (var k = 0; k < items.length; k++)
                _push(rows, items[k], names[n], o, recent.indexOf(items[k].id) >= 0);
        }
    }
    if (o.showUnconnected !== false && o.kind !== "agent") {
        var words = _words(o.query);
        var offline = (o.unconnected || []).filter(function (pv) {
            return _matches(words, (pv.label + " " + pv.id).toLowerCase());
        });
        if (offline.length > 0) {
            rows.push({ type: "header", key: "h:unconnected", group: "unconnected" });
            for (var u = 0; u < offline.length; u++)
                rows.push({ type: "provider", key: "p:" + offline[u].id, group: "unconnected", provider: offline[u] });
        }
    }
    return rows;
}

// Whether a row can be focused/activated (headers and agent status/manual
// rows cannot; unavailable models can be focused but not picked).
function selectable(row) {
    return !!row && row.type !== "header" && row.type !== "agentStatus" && row.type !== "agentManual";
}

// Next selectable index from `index` in direction `step` (+1/-1), clamped.
function step(rows, index, dir) {
    var i = index;
    for (;;) {
        i += dir;
        if (i < 0 || i >= rows.length)
            return index;
        if (selectable(rows[i]))
            return i;
    }
}

// First selectable index, preferring the current agent model, then the
// row of `currentId`.
function initialIndex(rows, currentId) {
    for (var c = 0; c < rows.length; c++)
        if (rows[c].type === "agentModel" && rows[c].current)
            return c;
    var first = -1;
    for (var i = 0; i < rows.length; i++) {
        if (!selectable(rows[i]))
            continue;
        if (first < 0)
            first = i;
        if (rows[i].type === "model" && rows[i].entry.id === currentId && !rows[i].recent)
            return i;
    }
    return first;
}
