.pragma library

// Engine of a space at startup. Assistant: the configured default, then the
// last explicit choice. Code (CLI agents only): the last agent, then the
// default agent.
function initial(primary, last) {
    return primary || last || "";
}

function initialCode(last, defaultAgent) {
    return last && last.indexOf("agent:") === 0 ? last : "agent:" + (defaultAgent || "claude");
}

// Space of a history entry: HTTP chats and assistant agent sessions (legacy
// "shell") belong to the Assistant, project agent sessions to Code.
function spaceOf(entry) {
    if (!entry || entry.kind !== "agent")
        return "assistant";
    return entry.mode === "assistant" || entry.mode === "shell" ? "assistant" : "code";
}

function resolve(models, id) {
    if (!id)
        return null;
    return models.find(m => m.id === id) || models.find(m => m.model === id || m.model.endsWith("/" + id)) || null;
}

function agentInput(text, attachments, capabilities) {
    const images = [];
    const contexts = [];
    for (const a of attachments || []) {
        if (a.type === "image") {
            if (!capabilities || !capabilities.images)
                return { error: "images" };
            if (!a.path)
                return { error: "image_path" };
            images.push(a.path);
        } else if (a.type === "text" && a.text) {
            const name = String(a.name || a.kind || "context").replace(/["<>]/g, "");
            contexts.push('<context name="' + name + '">\n' + a.text + '\n</context>');
        }
    }
    return { prompt: contexts.length ? contexts.join("\n\n") + "\n\n" + text : text, images: images };
}

function sessions(stored, live, agents, query, space) {
    const chats = {};
    for (const c of (stored || []).concat(live || []))
        chats[c.id] = Object.assign({}, chats[c.id] || {}, c);
    const out = Object.keys(chats).map(id => {
        const c = chats[id];
        return Object.assign({}, c, { kind: "chat", status: c.busy ? "running" : "idle", subtitle: c.model || c.preview || "" });
    }).concat((agents || []).map(s => Object.assign({}, s, {
        kind: "agent", subtitle: [s.agent, s.model].concat(spaceOf({ kind: "agent", mode: s.mode }) === "code" ? [s.cwd] : []).filter(Boolean).join(" · ")
    })));
    const words = String(query || "").toLowerCase().trim().split(/\s+/).filter(Boolean);
    return out.filter(e => !space || spaceOf(e) === space)
        .filter(e => words.every(w => [e.title, e.subtitle, e.search, e.lastText].join(" ").toLowerCase().includes(w)))
        .sort((a, b) => (Number(!!b.pinned) - Number(!!a.pinned)) || ((b.updated || 0) - (a.updated || 0)));
}

// Code history grouped by project (working directory), most recent project
// first; entries keep their order inside a group.
function byProject(entries) {
    const groups = [];
    const index = {};
    for (const e of entries || []) {
        const dir = e.cwd || "";
        if (index[dir] === undefined) {
            index[dir] = groups.length;
            groups.push({ project: dir, name: dir.split("/").filter(Boolean).pop() || dir || "~", entries: [], updated: 0 });
        }
        const g = groups[index[dir]];
        g.entries.push(e);
        g.updated = Math.max(g.updated, e.updated || 0);
    }
    return groups.sort((a, b) => b.updated - a.updated);
}

// Flat rows for a ListView: a header row before each project's entries.
function projectRows(entries) {
    const rows = [];
    for (const g of byProject(entries)) {
        rows.push({ header: true, project: g.project, name: g.name, count: g.entries.length });
        for (const e of g.entries)
            rows.push(Object.assign({ header: false }, e));
    }
    return rows;
}
