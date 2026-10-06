pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.store
import "ai"
import "ai/EngineSelection.js" as Selection
import "ai/ContextMath.js" as ContextMath

// Public assistant facade. Session ownership, request routing and prompt expansion
// live in focused collaborators and survive unloading the workspace UI.
Singleton {
    id: root
    readonly property bool enabled: Config.ai.enabled !== false
    property bool initialized: false
    property ModelCatalog catalog: null
    property ChatStore store: null
    property McpBridge mcp: null
    property AgentSessions agents: null
    property ContextGrabber context: null
    property ConversationSessions drafts: null
    property var chat: null
    property var quick: null
    property var automations: null
    property var selection: null
    // Engine kind of the visible conversation: chat (HTTP) | agent (CLI).
    property string mode: "chat"
    readonly property string space: GlobalStates.aiSpace
    property string currentModelId: ""
    property string noticeError: ""
    property string _openingChatId: ""
    property int _newSerial: 0
    property var _agentOverrides: ({})
    readonly property string defaultModelId: space === "code" ? "agent:" + (Config.ai.agents.defaultAgent || "claude") : (Config.ai.defaultModel || "")
    property var recentModelIds: []

    readonly property var models: catalog ? catalog.models : []
    readonly property var currentModel: catalog ? catalog.find(currentModelId) : null
    readonly property var quickModel: catalog ? catalog.find(Config.ai.quickAsk.model || Config.ai.defaultModel || currentModelId) : null
    readonly property var activeChat: mode === "agent" ? null : chat
    readonly property var activeAgent: mode === "agent" && agents ? agents.active : null
    readonly property bool busy: runner.starting || contextState.compacting || (activeAgent ? ["running", "starting", "waiting"].indexOf(activeAgent.status) >= 0 : (activeChat ? activeChat.busy : false))
    readonly property string sessionKey: activeAgent ? "agent:" + activeAgent.id : (mode === "agent" ? "new:" + space + ":" + currentModelId + ":" + _newSerial : (activeChat ? "chat:" + activeChat.chatId : ""))
    readonly property var agentSettings: {
        const id = activeAgent ? activeAgent.agent : (currentModel?.agent || Config.ai.agents.defaultAgent);
        const cfg = Config.ai.agents[id] || {};
        // Assistant agents work from $HOME and always ask before acting.
        const assistant = space !== "code" ? {
            cwd: Quickshell.env("HOME"),
            yolo: false,
            systemPrompt: ""
        } : {};
        const s = Object.assign({
            agent: id,
            model: cfg.model || "",
            effort: "",
            cwd: Config.ai.agents.defaultCwd || "",
            systemPrompt: "",
            yolo: !!cfg.yolo
        }, _agentOverrides[space + ":" + id] || {}, assistant, activeAgent || {});
        // New sessions start with the level last chosen for this model.
        if (!s.effort && !activeAgent) {
            const remembered = effort.rememberedFor(id, s.model);
            s.effort = remembered !== null ? remembered : (cfg.effort || "");
        }
        return s;
    }

    signal modelSelectionRequested
    signal focusComposerRequested

    property RequestRunner runner: RequestRunner {
        owner: root
    }
    property PromptActions promptActions: PromptActions {
        owner: root
    }
    property SpaceState spaces: SpaceState {
        owner: root
    }
    // Reasoning effort per model, and the visible conversation's context window.
    property EffortState effort: EffortState {
        owner: root
    }
    property ContextState contextState: ContextState {
        owner: root
    }
    readonly property Component catalogC: Component {
        ModelCatalog {}
    }
    readonly property Component storeC: Component {
        ChatStore {}
    }
    readonly property Component mcpC: Component {
        McpBridge {}
    }
    readonly property Component agentsC: Component {
        AgentSessions {}
    }
    readonly property Component contextC: Component {
        ContextGrabber {}
    }
    readonly property Component poolC: Component {
        ConversationSessions {}
    }
    readonly property Component sessionC: Component {
        ChatSession {}
    }
    readonly property Component agentPromptC: Component {
        AgentPrompt {}
    }
    readonly property Component automationsC: Component {
        AiAutomations {}
    }
    readonly property Component selectionC: Component {
        SelectionActions {}
    }

    function _ensureInit() {
        if (initialized || !enabled)
            return;
        initialized = true;
        catalog = catalogC.createObject(root);
        store = storeC.createObject(root);
        mcp = mcpC.createObject(root);
        agents = agentsC.createObject(root);
        context = contextC.createObject(root);
        drafts = poolC.createObject(root, {
            makeSession: (kind, persist) => _newSession(kind, persist)
        });
        currentModelId = Selection.initial(Config.ai.defaultModel, StateService.initialized ? StateService.get("lastAiModel", "") : "");
        recentModelIds = StateService.initialized ? StateService.get("aiRecentModels", []) : [];
        effort.init();
        drafts.selected.connect(s => {
            mode = "chat";
            chat = s;
            currentModelId = s.engineId;
            _configureSession(s);
        });
        chat = drafts.newSession("chat", true, currentModelId);
        quick = _newSession("quick", false);
        store.loaded.connect((id, data) => {
            if (id !== _openingChatId)
                return;
            _openingChatId = "";
            drafts.open(Array.isArray(data) ? {
                id: id,
                messages: data
            } : Object.assign({}, data, {
                id: id
            }));
        });
        agents.agentsChanged.connect(() => catalog.setAgents(agents.agents));
        agents.sessionsChanged.connect(() => spaces.retryRestore());
        agents.operationError.connect(message => {
            noticeError = message;
        });
        catalog.refresh();
        store.refresh();
        mcp.configure();
        agents.start();
        if (currentModelId.startsWith("agent:"))
            mode = "agent";
        spaces.init();
    }

    function _newSession(kind, persist) {
        const s = sessionC.createObject(root, {
            mode: kind,
            persist: persist
        }) as ChatSession;
        s.callTool = (server, tool, args, cb) => mcp.call(server, tool, args, cb);
        s.saveRequested.connect(data => store.save(data));
        _configureSession(s);
        return s;
    }

    function _configureSession(s) {
        if (!s || s.busy)
            return;
        const m = catalog ? catalog.find(s.engineId || currentModelId) : null;
        s.model = m && m.kind !== "agent" ? m : null;
        s.apiKey = m ? KeyStore.getKey(m.provider) || "" : "";
        s.customCurl = m ? KeyStore.getCustomCurl(m.provider) || "" : "";
        s.maxRounds = Config.ai.maxToolRounds || 8;
        s.policy = {
            autoApprove: Config.ai.agents.autoApprove || ["read"]
        };
        s.system = Config.ai.systemPrompt;
        const request = requestOptions(s.model);
        s.effort = request.effort;
        s.numCtx = request.numCtx;
        // Assistant chats (legacy "shell" chats included) get the MCP tools.
        s.tools = mcp && s.mode !== "quick" && s.mode !== "oneshot" && Config.ai.chatTools ? mcp.toolsFor("all") : [];
    }

    // Per-request settings of an HTTP model: its effort level and, for
    // Ollama, the context length to allocate.
    function requestOptions(m) {
        if (!m || m.kind === "agent")
            return {
                effort: "",
                numCtx: 0
            };
        return {
            effort: effort.levelFor(m),
            numCtx: m.provider === "ollama" ? ContextMath.numCtx(m.info ? m.info.contextWindow : 0, Config.ai.ollama.numCtx) : 0
        };
    }

    function _reconfigure() {
        for (const s of drafts ? drafts.sessions : [])
            _configureSession(s);
    }
    onCurrentModelChanged: _reconfigure()
    Connections {
        target: root.mcp
        function onAllToolsChanged() {
            root._reconfigure();
        }
    }
    Connections {
        target: KeyStore
        function onKeysChanged() {
            if (root.catalog)
                root.catalog.refresh();
            root._reconfigure();
        }
    }
    Connections {
        target: GlobalStates
        function onAssistantVisibleChanged() {
            if (GlobalStates.assistantVisible)
                root._ensureInit();
        }
        function onAiSpaceChanged() {
            if (root.initialized)
                root.spaces.sync();
        }
    }
    onSessionKeyChanged: spaces.remember(sessionKey)

    readonly property bool _wantsAutomations: enabled && (Config.ai.automations || []).some(a => a && a.enabled)
    on_WantsAutomationsChanged: _syncAutomations()
    Component.onCompleted: _syncAutomations()
    function _syncAutomations() {
        if (_wantsAutomations && !automations)
            automations = automationsC.createObject(root);
        else if (!_wantsAutomations && automations) {
            automations.destroy();
            automations = null;
        }
    }

    function setModel(id) {
        _ensureInit();
        _openingChatId = "";
        const m = catalog.find(id);
        if (!m || m.available === false) {
            noticeError = I18n.t("ai.engine_unavailable");
            return false;
        }
        if (space === "code" && m.kind !== "agent") {
            noticeError = I18n.t("ai.code_needs_agent");
            return false;
        }
        noticeError = "";
        if (m.kind === "agent") {
            if (!activeAgent || activeAgent.agent !== m.agent)
                agents.activeId = "";
            mode = "agent";
        } else {
            if (mode === "agent" || !chat || (chat.engineId !== m.id && (busy || chat.rows.count > 0)))
                chat = drafts.newSession("chat", true, m.id);
            chat.engineId = m.id;
            mode = "chat";
        }
        currentModelId = m.id;
        StateService.set(space === "code" ? "lastAiCodeModel" : "lastAiModel", m.id);
        recentModelIds = [m.id].concat(recentModelIds.filter(x => x !== m.id)).slice(0, 8);
        StateService.set("aiRecentModels", recentModelIds);
        _reconfigure();
        return true;
    }

    // Default engine of the visible space: Code remembers the agent,
    // the Assistant any engine.
    function setDefaultModel(id) {
        if (space === "code" && id.startsWith("agent:"))
            SettingsStore.set("ai.agents.defaultAgent", id.substring(6));
        else
            SettingsStore.set("ai.defaultModel", id);
    }

    function configureAgent(fields) {
        if (busy)
            return false;
        if (activeAgent)
            agents.update(activeAgent.id, fields);
        else {
            const id = space + ":" + agentSettings.agent;
            _agentOverrides = Object.assign({}, _agentOverrides, {
                [id]: Object.assign({}, _agentOverrides[id] || {}, fields)
            });
        }
        return true;
    }

    // Shows a space: "assistant" | "code" (legacy: chat/shell -> assistant,
    // agent -> code). Each space keeps its own engine and conversation.
    function setSpace(value) {
        _ensureInit();
        GlobalStates.aiSpace = value === "code" || value === "agent" ? "code" : "assistant";
    }

    function newConversation() {
        _ensureInit();
        _openingChatId = "";
        const id = space === "code" ? currentModelId : (Config.ai.defaultModel || currentModelId);
        _newSerial++;
        noticeError = "";
        if (id.startsWith("agent:")) {
            agents.activeId = "";
            currentModelId = id;
            mode = "agent";
        } else {
            chat = drafts.newSession("chat", true, id);
        }
        focusComposerRequested();
    }

    function openConversation(kind, id) {
        _ensureInit();
        _openingChatId = "";
        noticeError = "";
        GlobalStates.aiSpace = spaces.spaceOf(kind, id);
        if (kind === "agent") {
            agents.activeId = id;
            mode = "agent";
            if (agents.active)
                currentModelId = "agent:" + agents.active.agent;
        } else if (!drafts.select(id)) {
            _openingChatId = id;
            store.load(id);
        }
    }

    function stopSession(kind, id) {
        runner.stopSession(kind, id);
    }

    // Reverts a tool call: `undo` is the descriptor a tool returned
    // ({server, tool, args, label}), run as another MCP call.
    function undoAction(undo, cb) {
        if (!mcp || !undo || !undo.tool) {
            if (cb)
                cb(false);
            return;
        }
        mcp.call(undo.server || "yozakura", undo.tool, undo.args || {}, result => {
            const failed = !result || result.isError;
            if (failed)
                noticeError = result ? result.text : I18n.t("ai.undo_failed");
            if (cb)
                cb(!failed);
        });
    }

    // Snapshot for the Assistant's suggestion chips.
    function ambientContext() {
        return context ? context.ambient() : ({});
    }

    // "Connect a model": the AI page of the settings window (`provider`, if
    // given, is the provider the user picked; the inline sheet uses it).
    signal connectProviderRequested(string provider)
    function openProviderSettings(provider) {
        connectProviderRequested(provider || "");
        GlobalStates.settingsCategory = "ai";
        GlobalStates.settingsWindowVisible = true;
    }

    function removeConversation(kind, id) {
        if (kind === "chat" && _openingChatId === id)
            _openingChatId = "";
        const wasSelected = kind === "agent" ? activeAgent?.id === id : activeChat?.chatId === id;
        runner.stopSession(kind, id);
        if (kind === "agent")
            agents.remove(id);
        else {
            drafts.remove(id);
            store.remove(id);
        }
        if (wasSelected) {
            const next = drafts.sessions.find(s => s.persist !== false);
            if (kind === "chat" && next)
                drafts.select(next.chatId);
            else
                newConversation();
        }
    }
    function renameConversation(kind, id, title) {
        if (kind === "agent")
            agents.update(id, {
                title: title
            });
        else {
            const s = drafts.sessions.find(x => x.chatId === id);
            if (s) {
                s.title = title;
                store.save(s.serialize());
                drafts.revision++;
            } else
                store.rename(id, title);
        }
    }
    function pinConversation(kind, id, pinned) {
        if (kind === "agent")
            agents.update(id, {
                pinned: pinned
            });
        else {
            const s = drafts.sessions.find(x => x.chatId === id);
            if (s) {
                s.pinned = pinned;
                store.save(s.serialize());
                drafts.revision++;
            } else
                store.setPinned(id, pinned);
        }
    }

    function send(text, attachments) {
        _ensureInit();
        if (text.trim() === "/new" || text.trim() === "/clear") {
            newConversation();
            return true;
        }
        if (text.trim() === "/model") {
            modelSelectionRequested();
            return true;
        }
        return runner.send(text, attachments || []);
    }
    function stop() {
        runner.stop();
    }
    function runPrompt(prompt, opts, cb) {
        _ensureInit();
        runner.runPrompt(prompt, opts, cb);
    }
    function askQuick(text, attachments) {
        _ensureInit();
        return runner.askQuick(text, attachments);
    }
    function continueInSidebar() {
        runner.continueInSidebar();
    }
    function handleVoice(text, target) {
        if (!enabled || !String(text || "").trim())
            return;
        if (target === "notch" || (!target && !GlobalStates.assistantVisible))
            askQuick(text, []);
        else
            send(text, []);
    }
    function expandTemplate(template, extra, cb) {
        promptActions.expandTemplate(template, extra, cb);
    }
    function runSelectionActions() {
        if (!enabled || !Config.ai.selection.enabled)
            return;
        _ensureInit();
        if (!selection)
            selection = selectionC.createObject(root);
        selection.open();
    }
    function askAboutRegion() {
        _ensureInit();
        context.screenshot(true, att => {
            if (att) {
                GlobalStates.quickAskAttachments = [att];
                GlobalStates.showQuickAsk();
            }
        });
    }
}
