import QtQuick
import qs.config
import qs.modules.services
import "ContextMath.js" as ContextMath
import "Compaction.js" as Compaction

// Context window of the visible conversation and compaction of HTTP chats.
// Agents report their window and usage with each finished turn (backend
// `done` events: usage.contextTokens / contextWindow) and compact
// themselves; HTTP chats use the model's window (per-model override >
// Ollama num_ctx > assets/ai/models.json) and the last turn's tokens.
QtObject {
    id: root
    property var owner

    readonly property var entry: owner ? owner.currentModel : null
    readonly property bool agentEngine: entry !== null && entry.kind === "agent"
    readonly property var chat: owner && !agentEngine ? owner.activeChat : null
    readonly property var agentUsage: {
        if (!owner || !owner.agents || !owner.activeAgent)
            return null;
        owner.agents.timelineRevision;
        const tl = owner.agents.peekTimeline(owner.activeAgent.id);
        return tl ? tl.state.usage : null;
    }
    readonly property var windowInfo: agentEngine ? ({
            window: agentUsage?.contextWindow || 0,
            source: agentUsage?.contextWindow ? "agent" : ""
        }) : ContextMath.windowFor(entry, Config.ai.context.overrides, Config.ai.ollama.numCtx)
    readonly property int window: windowInfo.window
    readonly property string source: windowInfo.source
    readonly property int used: agentEngine ? (agentUsage?.contextTokens || 0) : (chat ? chat.contextTokens : 0)
    readonly property real fraction: ContextMath.fraction(used, window)
    readonly property string level: ContextMath.level(fraction, Config.ai.context.warnAt, Config.ai.context.criticalAt)
    readonly property bool compacting: compactor.running
    // HTTP chat with older turns than the ones compaction keeps.
    readonly property bool canCompact: {
        if (!chat || chat.busy || compactor.running)
            return false;
        chat.rows.count;
        return Compaction.plan(_rows(chat), Config.ai.context.keepTurns) !== null;
    }

    property ChatCompactor compactor: ChatCompactor {}

    function _rows(session) {
        const out = [];
        for (let i = 0; i < session.rows.count; i++)
            out.push(session.rows.get(i));
        return out;
    }

    // Model that writes the summary: the configured compaction model, else
    // the chat's own.
    function _compactModel(session) {
        const id = Config.ai.context.compactModel || "";
        const m = id && owner.catalog ? owner.catalog.find(id) : null;
        return m && m.kind !== "agent" && m.available !== false ? m : session.model;
    }

    function fractionFor(session) {
        const m = session ? session.model : null;
        const w = ContextMath.windowFor(m, Config.ai.context.overrides, Config.ai.ollama.numCtx).window;
        return ContextMath.fraction(session ? session.contextTokens : 0, w);
    }

    // Whether sending in `session` should compact first.
    function needsAutoCompact(session) {
        if (!session || !Compaction.shouldAutoCompact(Config.ai.context.autoCompact, fractionFor(session), Config.ai.context.autoCompactAt))
            return false;
        return Compaction.plan(_rows(session), Config.ai.context.keepTurns) !== null;
    }

    // cb(ok, aborted): a failed compaction still lets the caller go on.
    function compact(session, cb) {
        const s = session || chat;
        const done = cb || (() => {});
        if (!s) {
            done(false);
            return;
        }
        const m = _compactModel(s);
        compactor.run(s, m, m ? KeyStore.getKey(m.provider) || "" : "", m ? KeyStore.getCustomCurl(m.provider) || "" : "", Config.ai.context.keepTurns, (ok, error, aborted) => {
            if (!ok && error)
                owner.noticeError = I18n.t("ai.compact_failed") + ": " + error;
            done(ok, !!aborted);
        });
    }
}
