import QtQuick
import qs.config
import qs.modules.services
import "Providers.js" as Providers
import "EngineSelection.js" as Selection

// Every selectable "model": API models (fetched with the user's keys), local
// Ollama models and CLI agents (Claude Code, Codex, OpenCode) reported by the
// backend agents service. Entry:
//   {id, name, model, provider, kind: api|local|agent, agent, icon, description,
//    endpoint, available, tools}
QtObject {
    id: root

    property var apiModels: []
    property var agentModels: []
    readonly property var models: agentModels.concat(apiModels)
    property int _generation: 0
    property int pending: 0
    readonly property bool fetching: pending > 0

    readonly property Component getter: Component {
        HttpGet {}
    }

    function iconFor(provider) {
        const p = Providers.PROVIDERS[provider];
        return Qt.resolvedUrl("../../../assets/aiproviders/" + (p ? p.icon : "openrouter.svg"));
    }

    function find(id) {
        return Selection.resolve(models, id);
    }

    function _entry(provider, item, endpoint) {
        const p = Providers.PROVIDERS[provider];
        return {
            id: provider + ":" + item.id,
            name: item.name || item.id,
            model: item.id,
            provider: provider,
            kind: p && p.local ? "local" : "api",
            agent: "",
            icon: iconFor(provider),
            description: item.description || (p ? p.label : provider),
            endpoint: endpoint || "",
            available: true,
            tools: true
        };
    }

    function _merge(provider, list) {
        const keep = apiModels.filter(m => m.provider !== provider);
        apiModels = keep.concat(list);
    }

    function _fetch(provider, url, headers, endpoint) {
        pending++;
        const generation = _generation;
        const g = getter.createObject(root);
        g.get(url, headers, (text, ok) => {
            pending = Math.max(0, pending - 1);
            if (!ok || generation !== _generation)
                return;
            const items = Providers.parseModelList(provider, text);
            _merge(provider, items.map(it => _entry(provider, it, endpoint)));
        });
    }

    function refresh() {
        _generation++;
        const keyed = ["openai", "anthropic", "mistral", "groq"];
        for (const id of keyed) {
            const key = KeyStore.getKey(id);
            if (!key) {
                _merge(id, []);
                continue;
            }
            const r = Providers.modelsRequest(id, key);
            _fetch(id, r.url, r.headers, "");
        }
        const gkey = KeyStore.getKey("gemini");
        if (gkey) {
            const g = Providers.modelsRequest("gemini", gkey);
            _fetch("gemini", g.url, g.headers, "");
        } else {
            _merge("gemini", []);
        }
        if (KeyStore.getKey("minimax"))
            _merge("minimax", Providers.MINIMAX_MODELS.map(m => _entry("minimax", {
                    id: m,
                    name: m
                })));
        else
            _merge("minimax", []);
        const customEndpoint = KeyStore.getEndpoint("custom");
        if (customEndpoint) {
            const ck = KeyStore.getKey("custom");
            _fetch("custom", customEndpoint.replace(/\/+$/, "") + "/models", ck ? ["Authorization: Bearer " + ck] : [], customEndpoint);
        } else {
            _merge("custom", []);
        }
        // Ollama is probed without a key; an unreachable daemon just yields nothing.
        if (KeyStore.hasKey("ollama")) {
            const ollamaBase = KeyStore.getEndpoint("ollama") || Providers.PROVIDERS.ollama.base;
            _fetch("ollama", ollamaBase.replace(/\/+$/, "") + "/api/tags", [], KeyStore.getEndpoint("ollama"));
        } else {
            _merge("ollama", []);
        }
        _addExtra();
    }

    function _addExtra() {
        const extra = Config.ai.extraModels || [];
        const list = [];
        for (const e of extra) {
            if (!e || !e.model)
                continue;
            const provider = e.provider || "custom";
            list.push(Object.assign(_entry(provider, {
                id: e.model,
                name: e.name || e.model
            }, e.endpoint || ""), {
                id: "extra:" + provider + ":" + e.model
            }));
        }
        apiModels = apiModels.filter(m => !m.id.startsWith("extra:")).concat(list);
    }

    // agents: [{id, label, available, version, notes, capabilities}] from agents.list_agents
    function setAgents(agents) {
        const labels = {
            claude: "Claude Code",
            codex: "Codex",
            opencode: "OpenCode"
        };
        const icons = {
            claude: "anthropic.svg",
            codex: "openai.svg",
            opencode: "openrouter.svg"
        };
        agentModels = (agents || []).filter(a => {
            const cfg = Config.ai.agents ? Config.ai.agents[a.id] : null;
            return !cfg || cfg.enabled !== false;
        }).map(a => ({
                    id: "agent:" + a.id,
                    name: a.label || labels[a.id] || a.id,
                    model: a.id,
                    provider: "agent",
                    kind: "agent",
                    agent: a.id,
                    icon: Qt.resolvedUrl("../../../assets/aiproviders/" + (icons[a.id] || "openrouter.svg")),
                    description: a.available ? (a.version || a.notes || "") : (a.notes || "not installed"),
                    endpoint: "",
                    available: !!a.available,
                    capabilities: a.capabilities || {},
                    tools: true
                }));
    }
}
