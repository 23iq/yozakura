import QtQuick
import qs.config
import qs.modules.services
import "EffortPrefs.js" as Prefs
import "Providers.js" as Providers

// Reasoning effort of the visible engine, remembered per model
// (StateService `aiModelEfforts`, see EffortPrefs.js). Changing it in a chat
// makes it the model's default: HTTP chats pick it up on their next request,
// CLI agents get it through configureAgent (the session, or the next launch).
QtObject {
    id: root
    property var owner
    property var memory: ({})

    readonly property var entry: owner ? owner.currentModel : null
    readonly property bool isAgent: entry !== null && entry.kind === "agent"
    readonly property var agentCatalog: {
        if (!isAgent || !owner.agents)
            return null;
        const s = owner.agentSettings || {};
        return owner.agents.settingsFor(s.agent, s.cwd);
    }
    // Levels the visible engine offers ([] hides the control), the current
    // one ("" = auto: the engine decides) and what auto means for agents.
    readonly property var levels: !entry ? [] : (isAgent ? Prefs.agentLevels(agentCatalog, owner.agentSettings.model) : Prefs.httpLevels(entry))
    readonly property string level: !entry ? "" : (isAgent ? (owner.agentSettings.effort || "") : Prefs.httpLevel(entry, memory, Config.ai.effort.defaultLevel))
    readonly property string autoHint: isAgent ? Prefs.agentDefault(agentCatalog, owner.agentSettings.model) : ""
    // What a new turn will use, shown before the first message: the model
    // ("Opus 5.5", resolved from the catalog default for agents) and the
    // concrete effort level ("" when the engine has none or decides alone).
    readonly property string modelLabel: !entry ? "" : (isAgent ? (Prefs.agentModelLabel(agentCatalog, owner.agentSettings.model) || (agentCatalog && agentCatalog.loading ? "…" : "")) : (entry.name || entry.model || ""))
    readonly property string effortLabel: level || autoHint
    // "Codex · GPT-5.5 · medium" / "Anthropic · Claude Sonnet 4.5".
    readonly property string summary: !entry ? "" : [isAgent ? entry.name : (Providers.provider(entry.provider).label || entry.provider), modelLabel, effortLabel].filter(x => !!x).join(" · ")
    readonly property string _catalogKey: isAgent ? (owner.agentSettings.agent || "") + "|" + (owner.agentSettings.cwd || "") : ""

    function init() {
        memory = StateService.initialized ? StateService.get("aiModelEfforts", {}) : {};
    }

    // Effort an HTTP catalog entry runs with ("" = send nothing).
    function levelFor(m) {
        return Prefs.httpLevel(m, memory, Config.ai.effort.defaultLevel);
    }

    // Remembered native effort of an agent model for new sessions
    // (null = never chosen, "" = auto).
    function rememberedFor(agent, model) {
        return Prefs.remembered(memory, agent, model);
    }

    // Loads the agent's model catalog when the strip needs its levels.
    function ensureAgentCatalog() {
        if (!isAgent || !owner.agents)
            return;
        const s = owner.agentSettings || {};
        if (!owner.agents.modelCatalogs.has(s.agent, s.cwd))
            owner.agents.refreshModels(s.agent, s.cwd);
    }
    on_CatalogKeyChanged: ensureAgentCatalog()

    function set(value) {
        if (!entry)
            return false;
        if (owner.busy)
            return owner.refuseBusy();
        const key = Prefs.memoryKey(entry, isAgent ? owner.agentSettings.model : "");
        memory = Prefs.remember(memory, key, value);
        if (StateService.initialized)
            StateService.set("aiModelEfforts", memory);
        if (isAgent)
            return owner.configureAgent({
                effort: value
            });
        owner._reconfigure();
        return true;
    }
}
