import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import "Providers.js" as Providers
import "ModelInfo.js" as ModelInfo
import "EngineSelection.js" as Selection

// Every selectable "model": API models (fetched with the user's keys), local
// Ollama models (backend providers.ollama.probe, with real capabilities) and
// CLI agents (Claude Code, Codex, OpenCode) reported by the backend agents
// service. Entry:
//   {id, name, model, provider, kind: api|local|agent, agent, icon, description,
//    endpoint, available, tools, images, info}
// `info` is the capability record (ModelInfo.js: contextWindow, vision, tools,
// reasoning, efforts, ...) from assets/ai/models.json or the Ollama probe.
QtObject {
    id: root

    property var apiModels: []
    property var agentModels: []
    readonly property var models: agentModels.concat(apiModels)
    property int _generation: 0
    property int pending: 0
    readonly property bool fetching: pending > 0
    property var table: null
    // Ollama state from the last probe: reachable, endpoint, error.
    property var ollama: ({
            reachable: false,
            endpoint: "",
            error: ""
        })
    property double _lastProbe: 0
    readonly property int probeInterval: 15000

    readonly property Component getter: Component {
        HttpGet {}
    }

    property FileView tableFile: FileView {
        path: Quickshell.shellDir + "/assets/ai/models.json"
        printErrors: false
        onLoaded: {
            try {
                root.table = JSON.parse(text());
            } catch (e) {
                root.table = null;
            }
            root.apiModels = root.apiModels.map(m => root._withInfo(m));
        }
    }

    function iconFor(provider) {
        const p = Providers.PROVIDERS[provider];
        return Qt.resolvedUrl("../../../assets/aiproviders/" + (p ? p.icon : "openrouter.svg"));
    }

    function find(id) {
        return Selection.resolve(models, id);
    }

    // Capability record of an entry (Ollama entries keep the probe's).
    function _withInfo(m) {
        if (m.kind === "agent")
            return m;
        const info = m.info && m.info.source === "ollama" ? m.info : Object.assign({}, ModelInfo.lookup(table, m.provider, m.model) || {});
        return Object.assign({}, m, {
            info: info,
            tools: info.tools !== false,
            images: info.vision !== false
        });
    }

    function _entry(provider, item, endpoint) {
        const p = Providers.PROVIDERS[provider];
        return _withInfo({
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
            tools: true,
            images: true,
            info: item.info || null
        });
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
        const keyed = ["openai", "anthropic", "mistral", "groq", "openrouter", "deepseek"];
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
        probeOllama(true);
        _addExtra();
    }

    // Lists the local Ollama models through the backend probe (no model is
    // loaded). Throttled unless `force`; called when the picker opens.
    function probeOllama(force) {
        const now = Date.now();
        if (!force && now - _lastProbe < probeInterval)
            return;
        _lastProbe = now;
        const generation = _generation;
        const endpoint = KeyStore.getEndpoint("ollama");
        pending++;
        BackendService.call("providers.ollama.probe", {
            endpoint: endpoint
        }, (res, err) => {
            pending = Math.max(0, pending - 1);
            if (generation !== _generation || endpoint !== KeyStore.getEndpoint("ollama"))
                return;
            if (err || !res) {
                _legacyOllama(endpoint);
                return;
            }
            ollama = {
                reachable: !!res.reachable,
                endpoint: res.endpoint || "",
                error: res.error || ""
            };
            const list = (res.models || []).filter(m => (m.capabilities || []).indexOf("embedding") < 0 || (m.capabilities || []).indexOf("completion") >= 0);
            _merge("ollama", list.map(m => _entry("ollama", {
                    id: m.id,
                    name: m.name || m.id,
                    description: [m.sizeLabel, m.quantization].filter(Boolean).join(" · "),
                    info: ModelInfo.fromOllama(m)
                }, endpoint)));
        });
    }

    // Older daemons without the providers service: the former opt-in
    // (an "ollama" keystore entry) and a direct /api/tags listing.
    function _legacyOllama(endpoint) {
        if (!KeyStore.hasKey("ollama")) {
            _merge("ollama", []);
            return;
        }
        const base = endpoint || Providers.PROVIDERS.ollama.base;
        _fetch("ollama", base.replace(/\/+$/, "") + "/api/tags", [], endpoint);
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
                    tools: true,
                    info: null
                }));
    }
}
