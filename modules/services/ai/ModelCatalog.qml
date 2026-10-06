import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import qs.modules.globals
import "Providers.js" as Providers
import "ProviderConnect.js" as Connect
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
    // LM Studio state from the last listing (same shape).
    property var lmstudio: ({
            reachable: false,
            endpoint: "",
            error: ""
        })
    property double _lastProbe: 0
    readonly property int probeInterval: 15000
    readonly property var providerConfig: Config.ai.providers ?? null
    readonly property var hidden: providerConfig?.hidden ?? []
    readonly property string ollamaEndpoint: Config.ai.ollama ? (Config.ai.ollama.endpoint || "") : ""
    readonly property string lmstudioEndpoint: Config.ai.lmstudio ? (Config.ai.lmstudio.endpoint || "") : ""

    onOllamaEndpointChanged: probeOllama(true)
    onLmstudioEndpointChanged: probeLmStudio(true)
    onHiddenChanged: Qt.callLater(refresh)

    function isHidden(provider) {
        return hidden.indexOf(provider) >= 0;
    }

    // Local providers are re-probed while the AI bar is open
    // (ai.providers.probeInterval seconds, 0 = only when the picker opens).
    property Timer autoProbe: Timer {
        interval: Math.max(5, root.providerConfig?.probeInterval ?? 0) * 1000
        repeat: true
        running: (root.providerConfig?.probeInterval ?? 0) > 0 && GlobalStates.assistantVisible
        onTriggered: root.probeLocal(false)
    }

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
        const info = m.info && m.info.source === "ollama" ? m.info : Object.assign({}, ModelInfo.lookup(table, m.provider, m.model) || m.hint || {});
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
            info: item.info || null,
            hint: item.hint || null
        });
    }

    function _merge(provider, list) {
        const keep = apiModels.filter(m => m.provider !== provider);
        apiModels = keep.concat(list);
    }

    // done(ok, text) is optional (LM Studio reachability).
    function _fetch(provider, url, headers, endpoint, done) {
        pending++;
        const generation = _generation;
        const g = getter.createObject(root);
        g.get(url, headers, (text, ok) => {
            pending = Math.max(0, pending - 1);
            if (generation !== _generation)
                return;
            const items = ok ? Providers.parseModelList(provider, text) : [];
            const listed = ok && (items.length > 0 || /"data"|"models"/.test(text));
            if (done)
                done(listed, text);
            if (!ok)
                return;
            _merge(provider, items.map(it => _entry(provider, it, endpoint)));
        });
    }

    function refresh() {
        _generation++;
        const keyed = ["openai", "anthropic", "gemini", "mistral", "groq", "openrouter", "deepseek"];
        for (const id of keyed) {
            const key = KeyStore.getKey(id);
            if (!key || isHidden(id)) {
                _merge(id, []);
                continue;
            }
            const endpoint = KeyStore.getEndpoint(id) || "";
            const r = Providers.modelsRequest(id, key, endpoint);
            _fetch(id, r.url, r.headers, endpoint);
        }
        if (KeyStore.getKey("minimax") && !isHidden("minimax"))
            _merge("minimax", Providers.MINIMAX_MODELS.map(m => _entry("minimax", {
                    id: m,
                    name: m
                })));
        else
            _merge("minimax", []);
        const customEndpoint = KeyStore.getEndpoint("custom");
        if (customEndpoint && !isHidden("custom")) {
            const c = Providers.modelsRequest("custom", KeyStore.getKey("custom"), customEndpoint, Connect.extraHeaders("custom", providerConfig));
            _fetch("custom", c.url, c.headers, customEndpoint);
        } else {
            _merge("custom", []);
        }
        probeLocal(true);
        _addExtra();
    }

    // Ollama and LM Studio (throttled unless `force`).
    function probeLocal(force) {
        probeOllama(force);
        probeLmStudio(force);
    }

    // LM Studio: its OpenAI-compatible /models listing (no key) is both the
    // model list and the reachability check.
    function probeLmStudio(force) {
        if (isHidden("lmstudio")) {
            lmstudio = {
                reachable: false,
                endpoint: "",
                error: ""
            };
            _merge("lmstudio", []);
            return;
        }
        const endpoint = Connect.baseUrl("lmstudio", lmstudioEndpoint);
        const r = Providers.modelsRequest("lmstudio", "", endpoint);
        _fetch("lmstudio", r.url, r.headers, endpoint, (ok, text) => {
            lmstudio = {
                reachable: ok,
                endpoint: endpoint,
                error: ok ? "" : (Providers.errorFromBody(text) || "unreachable")
            };
            if (!ok)
                _merge("lmstudio", []);
        });
    }

    // Lists the local Ollama models through the backend probe (no model is
    // loaded). Throttled unless `force`; called when the picker opens.
    function probeOllama(force) {
        const now = Date.now();
        if (!force && now - _lastProbe < probeInterval)
            return;
        _lastProbe = now;
        if (isHidden("ollama")) {
            ollama = {
                reachable: false,
                endpoint: "",
                error: ""
            };
            _merge("ollama", []);
            return;
        }
        const generation = _generation;
        const endpoint = ollamaEndpoint;
        pending++;
        BackendService.call("providers.ollama.probe", {
            endpoint: endpoint
        }, (res, err) => {
            pending = Math.max(0, pending - 1);
            if (generation !== _generation || endpoint !== ollamaEndpoint)
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

    // Older daemons without the providers service: a direct /api/tags
    // listing (reachable = connected, like the probe).
    function _legacyOllama(endpoint) {
        const base = Connect.baseUrl("ollama", endpoint);
        _fetch("ollama", base.replace(/\/+$/, "") + "/api/tags", [], endpoint, ok => {
            ollama = {
                reachable: ok,
                endpoint: base,
                error: ok ? "" : "unreachable"
            };
            if (!ok)
                _merge("ollama", []);
        });
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
