import QtQuick
import qs.config
import qs.modules.services
import "EngineSelection.js" as Selection

// "Set once, stays": the engine and CLI-agent model the user last picked,
// per space, persisted in StateService so new chats, new sessions, restarts
// and Quick ask (when ai.quickAsk.model is empty) use them.
//   aiEngines      {assistant: {id, base}, code: {id, base}}; `base` is the
//                  configured default at pick time (EngineSelection.start)
//   aiAgentModels  {"assistant:claude": "haiku", "code:codex": "gpt-5.5"};
//                  "" = the agent's own default model
// The effort level is remembered per model by EffortState (aiModelEfforts).
// Legacy keys lastAiModel / lastAiCodeModel are read once and kept written.
QtObject {
    id: root
    property var picks: ({})
    property var agentModels: ({})

    function _get(key, fallback) {
        return StateService.initialized ? StateService.get(key, fallback) : fallback;
    }
    function _set(key, value) {
        if (StateService.initialized)
            StateService.set(key, value);
    }

    function init() {
        const stored = _get("aiEngines", null);
        picks = stored && typeof stored === "object" ? stored : {
            assistant: _get("lastAiModel", "") || null,
            code: _get("lastAiCodeModel", "") || null
        };
        const models = _get("aiAgentModels", null);
        agentModels = models && typeof models === "object" ? models : {};
    }

    function defaultFor(space) {
        return space === "code" ? "agent:" + (Config.ai.agents.defaultAgent || "claude") : (Config.ai.defaultModel || "");
    }

    // Engine id a new conversation of `space` uses.
    function engine(space) {
        return space === "code" ? Selection.startCode(Config.ai.agents.defaultAgent, picks.code) : Selection.start(defaultFor("assistant"), picks.assistant);
    }

    function remember(space, id) {
        if (!id)
            return;
        const s = space === "code" ? "code" : "assistant";
        picks = Object.assign({}, picks, {
            [s]: {
                id: id,
                base: defaultFor(s)
            }
        });
        _set("aiEngines", picks);
        _set(s === "code" ? "lastAiCodeModel" : "lastAiModel", id);
    }

    // Native model of `agent` in `space`: undefined = never picked.
    function agentModel(space, agent) {
        return agentModels[(space === "code" ? "code" : "assistant") + ":" + agent];
    }

    function rememberAgentModel(space, agent, model) {
        agentModels = Object.assign({}, agentModels, {
            [(space === "code" ? "code" : "assistant") + ":" + agent]: model || ""
        });
        _set("aiAgentModels", agentModels);
    }
}
