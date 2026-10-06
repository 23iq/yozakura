import QtQuick
import qs.config
import qs.modules.services
import qs.modules.globals
import "EngineSelection.js" as Selection
import "Providers.js" as Providers

// Transport decisions and deferred sends stay here, outside the UI facade.
QtObject {
    id: root
    property var owner
    property var pending: ({})
    readonly property bool starting: !!pending[owner.sessionKey]
    property int _serial: 0

    function forget(key) {
        const next = Object.assign({}, pending);
        delete next[key];
        pending = next;
    }

    function error(key) {
        owner.noticeError = I18n.t(key);
        return false;
    }

    function supportsAttachments(model, attachments) {
        if (model.kind === "agent")
            return true;
        return !(attachments || []).some(a => a && a.type === "image") || (Providers.provider(model.provider).images && model.images !== false);
    }

    function send(text, attachments) {
        if (!String(text || "").trim() && !(attachments || []).length)
            return false;
        if (owner.busy)
            return false;
        const m = owner.currentModel;
        if (!m || m.available === false)
            return error("ai.engine_unavailable");
        if (!supportsAttachments(m, attachments))
            return error("ai.unsupported_attachment");
        owner.noticeError = "";
        if (m.kind === "agent") {
            const info = owner.agents.agents.find(a => a.id === m.agent);
            const input = Selection.agentInput(text, attachments, info?.capabilities);
            if (input.error)
                return error("ai.unsupported_attachment");
            if (owner.activeAgent) {
                owner.agents.send(owner.activeAgent.id, input.prompt, input.images);
            } else {
                const settings = owner.agentSettings;
                const key = owner.sessionKey;
                const generation = ++_serial;
                pending = Object.assign({}, pending, {
                    [key]: generation
                });
                owner.agents.create(m.agent, settings.cwd, Object.assign({}, settings, {
                    mode: owner.space === "code" ? "agent" : "assistant",
                    prompt: input.prompt,
                    images: input.images,
                    activate: false,
                    onCreated: meta => {
                        const cancelled = pending[key] !== generation;
                        if (!cancelled)
                            forget(key);
                        if (cancelled)
                            owner.agents.close(meta.id);
                        else if (owner.sessionKey === key)
                            owner.openConversation("agent", meta.id);
                        return !cancelled;
                    },
                    onError: () => {
                        if (pending[key] === generation)
                            forget(key);
                    }
                }));
            }
            return true;
        }
        const session = owner.activeChat;
        if (!session)
            return false;
        owner._configureSession(session);
        if (Config.ai.chatTools && !owner.mcp.allLoaded && BackendService.socketAvailable) {
            const key = "chat:" + session.chatId;
            const generation = ++_serial;
            pending = Object.assign({}, pending, {
                [key]: generation
            });
            owner.mcp.loadAll(() => {
                if (generation !== pending[key])
                    return;
                forget(key);
                owner._configureSession(session);
                _sendChat(session, text, attachments);
            });
            return true;
        }
        return _sendChat(session, text, attachments);
    }

    // Nearly full window: summarise older turns before sending.
    function _sendChat(session, text, attachments) {
        if (owner.contextState.needsAutoCompact(session)) {
            owner.contextState.compact(session, (ok, aborted) => {
                if (!aborted)
                    session.send(text, attachments || []);
            });
            return true;
        }
        return session.send(text, attachments || []);
    }

    function stop() {
        forget(owner.sessionKey);
        owner.contextState.compactor.abort();
        if (owner.activeAgent)
            owner.agents.cancel(owner.activeAgent.id);
        else if (owner.activeChat)
            owner.activeChat.stop();
    }

    function stopSession(kind, id) {
        forget(kind + ":" + id);
        if (kind === "agent")
            owner.agents.cancel(id);
        else {
            const s = owner.drafts.sessions.find(x => x.chatId === id);
            if (s)
                s.stop();
        }
    }

    function promptSession(m, opts) {
        if (m.kind === "agent") {
            const cfg = Config.ai.agents[m.agent] || {};
            const nativeModel = opts.nativeModel || cfg.model || "";
            const remembered = owner.effort.rememberedFor(m.agent, nativeModel);
            return owner.agentPromptC.createObject(owner, {
                owner: owner.agents,
                model: m,
                cwd: opts.cwd || "",
                nativeModel: nativeModel,
                effort: opts.effort || (remembered !== null ? remembered : (cfg.effort || "")),
                system: opts.system || Config.ai.systemPrompt
            });
        }
        const session = owner._newSession("oneshot", false);
        session.engineId = m.id;
        session.model = m;
        session.apiKey = KeyStore.getKey(m.provider) || "";
        session.customCurl = KeyStore.getCustomCurl(m.provider) || "";
        session.system = opts.system || Config.ai.systemPrompt;
        const request = owner.requestOptions(m);
        session.effort = request.effort;
        session.numCtx = request.numCtx;
        session.tools = [];
        session.maxRounds = 1;
        return session;
    }

    function runPrompt(prompt, opts, cb) {
        const o = opts || {};
        const m = o.model ? owner.catalog.find(o.model) : owner.quickModel;
        if (!m || m.available === false) {
            cb("", I18n.t("ai.engine_unavailable"));
            return;
        }
        if (!supportsAttachments(m, o.attachments)) {
            cb("", I18n.t("ai.unsupported_attachment"));
            return;
        }
        const s = promptSession(m, o);
        s.turnFinished.connect((text, err) => {
            cb(text, err);
            s.destroy();
        });
        if (!s.send(prompt, o.attachments || [])) {
            cb("", I18n.t("ai.unsupported_attachment"));
            s.destroy();
        }
    }

    function askQuick(text, attachments) {
        if (owner.quick?.busy)
            return false;
        const m = owner.quickModel;
        if (!m || m.available === false)
            return error("ai.engine_unavailable");
        if (!supportsAttachments(m, attachments))
            return error("ai.unsupported_attachment");
        const s = promptSession(m, {
            system: Config.ai.systemPrompt
        });
        if (!s.send(text, attachments || [])) {
            s.destroy();
            return error("ai.unsupported_attachment");
        }
        const previous = owner.quick;
        owner.quick = s;
        if (previous && owner.drafts.sessions.indexOf(previous) < 0)
            previous.destroy();
        owner.noticeError = "";
        GlobalStates.showQuickAsk();
        return true;
    }

    function continueInSidebar() {
        const s = owner.quick;
        if (!s)
            return;
        if (s.model?.kind === "agent") {
            if (!s.chatId)
                return;
            owner.openConversation("agent", s.chatId);
        } else {
            s.persist = true;
            s.mode = "chat";
            if (owner.drafts.sessions.indexOf(s) < 0)
                owner.drafts.registerSession(s);
            owner.drafts.select(s.chatId);
            owner.store.save(s.serialize());
        }
        GlobalStates.hideQuickAsk();
        if (!GlobalStates.assistantVisible)
            GlobalStates.toggleAssistant();
    }
}
