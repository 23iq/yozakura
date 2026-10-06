.pragma library

function initial(primary, last, legacyMode, legacyAgent, legacyShell) {
    return primary || last || (legacyMode === "agent" ? "agent:" + legacyAgent : (legacyMode === "shell" ? legacyShell || "" : ""));
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

function sessions(stored, live, agents, query) {
    const chats = {};
    for (const c of (stored || []).concat(live || []))
        chats[c.id] = Object.assign({}, chats[c.id] || {}, c);
    const out = Object.keys(chats).map(id => {
        const c = chats[id];
        return Object.assign({}, c, { kind: "chat", status: c.busy ? "running" : "idle", subtitle: c.model || c.preview || "" });
    }).concat((agents || []).map(s => Object.assign({}, s, {
        kind: "agent", subtitle: [s.agent, s.model, s.cwd].filter(Boolean).join(" · ")
    })));
    const words = String(query || "").toLowerCase().trim().split(/\s+/).filter(Boolean);
    return out.filter(e => words.every(w => [e.title, e.subtitle, e.search, e.lastText].join(" ").toLowerCase().includes(w)))
        .sort((a, b) => (Number(!!b.pinned) - Number(!!a.pinned)) || ((b.updated || 0) - (a.updated || 0)));
}
