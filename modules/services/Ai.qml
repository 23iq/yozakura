pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.globals
import "ai"
import "ai/Templates.js" as Templates

// AI center facade. Everything heavy is created on first use (_ensureInit),
// so a shell that never opens the AI center pays almost nothing at startup.
//   modes: chat (API/local models, MCP tools), agent (CLI agents via the Go
//   agents service), shell (desktop control through the yozakura MCP tools)
Singleton {
    id: root

    readonly property bool enabled: Config.ai.enabled !== false
    property bool initialized: false

    property ModelCatalog catalog: null
    property ChatStore store: null
    property McpBridge mcp: null
    property AgentSessions agents: null
    property ContextGrabber context: null
    property ChatSession chat: null
    property ChatSession shellChat: null
    property ChatSession quick: null
    property var automations: null
    property var selection: null

    property string mode: Config.ai.defaultMode || "chat"
    property string currentModelId: ""
    readonly property var models: catalog ? catalog.models : []
    readonly property var currentModel: catalog ? (catalog.find(currentModelId) || catalog.apiModels[0] || null) : null
    readonly property var quickModel: catalog ? (catalog.find(Config.ai.quickAsk.model) || currentModel) : null
    readonly property var activeChat: mode === "shell" ? shellChat : chat
    readonly property bool busy: activeChat ? activeChat.busy : false

    signal modelSelectionRequested
    signal focusComposerRequested

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
    readonly property Component sessionC: Component {
        ChatSession {}
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
        chat = _newSession("chat", true);
        shellChat = _newSession("shell", true);
        quick = _newSession("quick", false);
        store.loaded.connect((id, data) => {
            const target = data && data.mode === "shell" ? shellChat : chat;
            target.load(data);
            mode = target === shellChat ? "shell" : "chat";
        });
        agents.agentsChanged.connect(() => catalog.setAgents(agents.agents));
        if (StateService.initialized)
            currentModelId = StateService.get("lastAiModel", "");
        catalog.refresh();
        store.refresh();
        mcp.configure();
        agents.start();
    }

    function _newSession(kind, persist) {
        const s = sessionC.createObject(root, {
            mode: kind,
            persist: persist
        });
        s.callTool = (server, tool, args, cb) => mcp.call(server, tool, args, cb);
        s.saveRequested.connect(data => store.save(data));
        _configureSession(s);
        return s;
    }

    function _configureSession(s) {
        if (!s)
            return;
        const m = s === quick ? quickModel : currentModel;
        s.model = m && m.kind !== "agent" ? m : null;
        s.apiKey = m ? (KeyStore.getKey(m.provider) || "") : "";
        s.customCurl = m ? (KeyStore.getCustomCurl(m.provider) || "") : "";
        s.maxRounds = Config.ai.maxToolRounds || 8;
        s.policy = {
            autoApprove: Config.ai.agents.autoApprove || ["read"]
        };
        if (s.mode === "shell") {
            s.system = Config.ai.shell.systemPrompt;
            s.tools = mcp ? mcp.toolsFor("yozakura") : [];
        } else {
            s.system = Config.ai.systemPrompt;
            s.tools = Config.ai.chatTools && mcp && s.mode === "chat" ? mcp.toolsFor("all") : [];
        }
    }

    function _reconfigure() {
        _configureSession(chat);
        _configureSession(shellChat);
        _configureSession(quick);
    }

    onCurrentModelChanged: _reconfigure()
    onQuickModelChanged: _configureSession(quick)
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
        target: StateService
        function onInitializedChanged() {
            if (StateService.initialized && root.initialized && !root.currentModelId)
                root.currentModelId = StateService.get("lastAiModel", "");
        }
    }
    Connections {
        target: GlobalStates
        function onAssistantVisibleChanged() {
            if (GlobalStates.assistantVisible)
                root._ensureInit();
        }
    }

    // Automations only exist when the user enabled at least one.
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

    // ── model / mode ────────────────────────────────────────────────────

    function setModel(id) {
        _ensureInit();
        const m = catalog.find(id);
        if (!m)
            return false;
        if (m.kind === "agent") {
            setMode("agent");
            Config.ai.agents.defaultAgent = m.agent;
            return true;
        }
        currentModelId = m.id;
        StateService.set("lastAiModel", m.id);
        return true;
    }

    function setMode(m) {
        _ensureInit();
        if (["chat", "agent", "shell"].indexOf(m) >= 0)
            mode = m;
    }

    function newConversation() {
        _ensureInit();
        if (mode === "agent")
            agents.activeId = "";
        else
            activeChat.clear();
        focusComposerRequested();
    }

    // ── sending ─────────────────────────────────────────────────────────

    function send(text, attachments) {
        _ensureInit();
        if (_slash(text))
            return true;
        if (mode === "agent") {
            const images = (attachments || []).filter(a => a.type === "image" && a.path).map(a => a.path);
            const prompt = _inlineText(text, attachments);
            if (agents.activeId)
                agents.send(agents.activeId, prompt, images);
            else
                agents.create(Config.ai.agents.defaultAgent, Config.ai.agents.defaultCwd, {
                    prompt: prompt,
                    images: images
                });
            return true;
        }
        if (mode === "shell" && Config.ai.shell.target.indexOf("agent:") === 0) {
            const agentId = Config.ai.shell.target.substring(6);
            const shellSession = agents.sessions.find(s => s.mode === "shell" && s.agent === agentId && s.status !== "exited");
            if (shellSession)
                agents.send(shellSession.id, text, []);
            else
                agents.create(agentId, Quickshell.env("HOME"), {
                    mode: "shell",
                    prompt: text,
                    title: I18n.t("ai.mode_shell"),
                    systemPrompt: Config.ai.shell.systemPrompt
                });
            return true;
        }
        if (mode === "chat" && Config.ai.chatTools && !mcp.allLoaded && BackendService.socketAvailable) {
            // First tool-capable message: start the imported MCP servers once.
            const session = activeChat;
            mcp.loadAll(() => {
                _configureSession(session);
                session.send(text, attachments || []);
            });
            return true;
        }
        _configureSession(activeChat);
        return activeChat.send(text, attachments || []);
    }

    function _inlineText(text, attachments) {
        const extra = (attachments || []).filter(a => a.type === "text" && a.text).map(a => "<context name=\"" + (a.name || a.kind) + "\">\n" + a.text + "\n</context>");
        return extra.length ? extra.join("\n\n") + "\n\n" + text : text;
    }

    function stop() {
        if (!initialized)
            return;
        if (mode === "agent" && agents.activeId)
            agents.cancel(agents.activeId);
        else if (activeChat)
            activeChat.stop();
    }

    function _slash(text) {
        const t = String(text || "").trim();
        if (!t.startsWith("/"))
            return false;
        const cmd = t.split(/\s+/)[0].toLowerCase();
        const arg = t.substring(cmd.length).trim();
        switch (cmd) {
        case "/new":
        case "/clear":
            newConversation();
            return true;
        case "/model":
            if (!arg)
                modelSelectionRequested();
            else {
                const m = models.find(x => x.name.toLowerCase().includes(arg.toLowerCase()) || x.model === arg);
                if (m)
                    setModel(m.id);
                else if (activeChat)
                    activeChat.notice(I18n.t("ai.model_not_found").replace("%1", arg));
            }
            return true;
        case "/chat":
        case "/agent":
        case "/shell":
            setMode(cmd.substring(1));
            if (arg)
                send(arg, []);
            return true;
        case "/help":
            if (activeChat)
                activeChat.notice(I18n.t("ai.help_message"));
            return true;
        }
        return false;
    }

    // ── one-shot prompts (automations, selection actions, quick ask) ────

    // opts: {model: id, system, onDelta(text)}; cb(text, error)
    function runPrompt(prompt, opts, cb) {
        _ensureInit();
        const o = opts || {};
        const m = catalog.find(o.model) || quickModel || currentModel;
        if (!m || m.kind === "agent") {
            cb("", I18n.t("ai.no_model"));
            return;
        }
        const s = sessionC.createObject(root, {
            mode: "oneshot",
            persist: false,
            model: m,
            apiKey: KeyStore.getKey(m.provider) || "",
            customCurl: KeyStore.getCustomCurl(m.provider) || "",
            system: o.system || Config.ai.systemPrompt,
            maxRounds: 1
        });
        s.turnFinished.connect((text, error) => {
            cb(text, error);
            s.destroy();
        });
        if (!s.send(prompt, o.attachments || [])) {
            cb("", "empty prompt");
            s.destroy();
        }
    }

    function askQuick(text, attachments) {
        _ensureInit();
        _configureSession(quick);
        if (!quick.busy)
            quick.clear();
        quick.send(text, attachments || []);
        GlobalStates.showQuickAsk();
    }

    // Moves the quick-ask exchange into the sidebar chat and opens it there.
    function continueInSidebar() {
        _ensureInit();
        if (GlobalStates.quickAskKind === "shell") {
            mode = "shell";
            GlobalStates.hideQuickAsk();
            if (!GlobalStates.assistantVisible)
                GlobalStates.toggleAssistant();
            return;
        }
        const data = quick.serialize();
        data.id = Date.now().toString();
        data.mode = "chat";
        chat.load(data);
        mode = "chat";
        quick.clear();
        GlobalStates.hideQuickAsk();
        if (!GlobalStates.assistantVisible)
            GlobalStates.toggleAssistant();
        store.save(chat.serialize());
    }

    // Voice entry point (voice pipeline): target "sidebar" or "notch".
    // Desktop commands go to shell mode (yozakura MCP), questions to chat.
    function handleVoice(text, target) {
        if (!enabled || !String(text || "").trim())
            return;
        _ensureInit();
        const t = target || (GlobalStates.assistantVisible ? "sidebar" : "notch");
        const imperative = /^(open|close|switch|set|change|turn|enable|disable|toggle|move|show|hide|mute|unmute|pause|play|next|previous|take|copy|apply|focus|dnd|abre|cierra|cambia|pon|включи|выключи|открой|закрой|поставь|смени|сделай)\b/i;
        if (Config.ai.shell.enabled && imperative.test(text.trim())) {
            mode = "shell";
            if (t === "sidebar") {
                send(text, []);
            } else {
                _configureSession(shellChat);
                shellChat.send(text, []);
                GlobalStates.showQuickAsk("shell");
            }
            return;
        }
        if (t === "sidebar") {
            mode = mode === "shell" ? "chat" : mode;
            send(text, []);
        } else {
            askQuick(text, []);
        }
    }

    // Fills a prompt-library template; reads selection/clipboard only when used.
    function expandTemplate(template, extra, cb) {
        _ensureInit();
        const vars = Object.assign({
            language: Config.ai.selection.language
        }, extra || {});
        const needed = Templates.variables(template).filter(v => vars[v] === undefined && (v === "selection" || v === "clipboard" || v === "window"));
        const next = () => {
            if (needed.length === 0) {
                cb(Templates.expand(template, vars));
                return;
            }
            const v = needed.shift();
            if (v === "selection")
                context.selectionText(t => {
                    vars.selection = t;
                    next();
                });
            else if (v === "clipboard")
                context.clipboardText(t => {
                    vars.clipboard = t;
                    next();
                });
            else
                context.activeWindow(a => {
                    vars.window = a ? a.text : "";
                    next();
                });
        };
        next();
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
            if (!att)
                return;
            GlobalStates.quickAskAttachments = [att];
            GlobalStates.showQuickAsk();
        });
    }
}
