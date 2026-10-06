import QtQuick
import qs.config
import qs.modules.services
import qs.modules.globals
import "EngineSelection.js" as Selection

// The AI bar has two spaces with separate engines and conversations:
// Assistant (any engine; CLI agents run in the backend "assistant" mode) and
// Code (CLI agents in project folders). Each space remembers its engine and
// open conversation; switching saves one and restores the other.
// GlobalStates.aiSpace is the visible space, persisted as `aiSpace`.
QtObject {
    id: root
    property var owner
    // space -> {modelId, chat, agentId, mode}
    property var saved: ({})
    property string shown: ""

    function startSpace() {
        const pref = Config.ai.behavior.defaultSpace;
        if (pref === "assistant" || pref === "code")
            return pref;
        const last = StateService.initialized ? StateService.get("aiSpace", "assistant") : "assistant";
        return last === "code" ? "code" : "assistant";
    }

    // Called once by the facade after the assistant state is set up.
    function init() {
        shown = "assistant";
        GlobalStates.aiSpace = startSpace();
        if (GlobalStates.aiSpace === "code")
            sync();
        else
            restoreLast("assistant");
    }

    function sync() {
        const to = GlobalStates.aiSpace === "code" ? "code" : "assistant";
        if (!shown || to === shown)
            return;
        const o = owner;
        saved = Object.assign({}, saved, {
            [shown]: {
                modelId: o.currentModelId,
                chat: o.chat,
                agentId: o.agents ? o.agents.activeId : "",
                mode: o.mode
            }
        });
        shown = to;
        if (StateService.initialized)
            StateService.set("aiSpace", to);
        const s = saved[to];
        if (s)
            restore(s);
        else
            enter(to);
        o.noticeError = "";
        o._reconfigure();
    }

    function restore(s) {
        const o = owner;
        if (s.chat && o.drafts.sessions.indexOf(s.chat) >= 0)
            o.chat = s.chat;
        o.currentModelId = s.modelId;
        o.mode = s.mode;
        o.agents.activeId = s.agentId && o.agents.sessions.some(x => x.id === s.agentId) ? s.agentId : "";
    }

    function enter(to) {
        const o = owner;
        const id = o.engineMemory.engine(to);
        o.agents.activeId = "";
        o.currentModelId = id;
        o.mode = to === "code" || id.startsWith("agent:") ? "agent" : "chat";
        restoreLast(to);
    }

    // Reopens the space's last conversation (ai.behavior.restoreLastSession).
    function restoreLast(space) {
        if (!Config.ai.behavior.restoreLastSession || !StateService.initialized)
            return;
        const last = StateService.get(space === "code" ? "aiLastCodeSession" : "aiLastSession", null);
        if (!last || !last.id)
            return;
        if (last.kind === "agent" && !owner.agents.sessions.some(x => x.id === last.id)) {
            // The session list arrives from the backend later.
            pendingRestore = {
                space: space,
                id: last.id
            };
            return;
        }
        owner.openConversation(last.kind, last.id);
    }

    property var pendingRestore: null
    function retryRestore() {
        const p = pendingRestore;
        if (!p || !owner.agents.sessions.some(x => x.id === p.id))
            return;
        pendingRestore = null;
        // Only while the user has not started anything else in that space.
        if (p.space === shown && !owner.agents.activeId && (p.space === "code" || owner.mode === "agent"))
            owner.openConversation("agent", p.id);
    }

    function remember(key) {
        if (!StateService.initialized || !shown)
            return;
        const m = /^(chat|agent):(.+)$/.exec(key || "");
        if (m)
            StateService.set(shown === "code" ? "aiLastCodeSession" : "aiLastSession", {
                kind: m[1],
                id: m[2]
            });
    }

    // Space a conversation belongs to.
    function spaceOf(kind, id) {
        if (kind !== "agent")
            return "assistant";
        const s = owner.agents.sessions.find(x => x.id === id);
        return Selection.spaceOf({
            kind: "agent",
            mode: s ? s.mode : "agent"
        });
    }
}
