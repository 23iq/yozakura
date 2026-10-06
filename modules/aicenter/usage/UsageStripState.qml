import QtQuick
import qs.modules.services
import qs.config
import "../../services/ai/UsageFormat.js" as UsageFormat

// What the composer strip shows about usage: the visible session's tokens
// and cost (ledger totals from UsageService) and the subscription window of
// the current engine (Claude Code / Codex), with tooltip texts.
QtObject {
    id: root

    readonly property string sessionId: Ai.activeAgent ? Ai.activeAgent.id : (Ai.activeChat ? Ai.activeChat.chatId : "")
    readonly property var totals: {
        UsageService.sessions;
        return UsageService.sessionTotals(sessionId);
    }
    readonly property var costOpts: ({
            style: Config.ai.usage.currencyStyle || "symbol",
            decimals: Config.ai.usage.decimals || 2
        })
    readonly property string costText: UsageFormat.stripText(totals, Object.assign({
        tokens: Config.ai.usage.stripTokens !== false
    }, costOpts))
    readonly property string costDetail: {
        const t = totals;
        if (!t || !(t.requests > 0))
            return "";
        const lines = [I18n.t("ai.usage.tokens_in_out").arg(UsageFormat.tokens(t.inputTokens)).arg(UsageFormat.tokens(t.outputTokens)), I18n.t("ai.usage.requests").arg(t.requests)];
        const c = UsageFormat.totalsCost(t, costOpts);
        if (c)
            lines.push(c + (t.estimated ? "  " + I18n.t("ai.usage.estimated_short") : ""));
        return lines.join("\n");
    }

    readonly property string subscription: UsageFormat.subscriptionFor(Ai.currentModel)
    readonly property var limit: {
        UsageService.limits;
        Config.ai.usage.limitWindow;
        return UsageService.limitFor(subscription);
    }
    readonly property real limitFraction: limit ? limit.fraction : -1
    readonly property string limitLevel: limit ? UsageFormat.level(limit.percent, Config.ai.usage.warnAt, Config.ai.usage.criticalAt) : "ok"
    readonly property string limitText: limit ? windowShort(limit.id) + " " + Math.round(limit.percent) + "%" : ""
    readonly property string limitTooltip: limit ? I18n.t("ai.usage.limit_of").arg(UsageFormat.providerLabel(limit.provider)).arg(windowLabel(limit.id)) : ""
    readonly property string limitDetail: {
        if (!limit)
            return "";
        const left = UsageFormat.msUntil(limit.resetsAt, UsageService.now);
        const used = I18n.t("ai.usage.used_percent").arg(Math.round(limit.percent));
        return left > 0 ? used + "\n" + I18n.t("ai.usage.resets_in").arg(UsageFormat.duration(left, units())) : used;
    }

    function units() {
        return {
            d: I18n.t("ai.usage.unit_d"),
            h: I18n.t("ai.usage.unit_h"),
            m: I18n.t("ai.usage.unit_m")
        };
    }
    function windowLabel(id) {
        const key = UsageFormat.windowKey(id);
        return key ? I18n.t(key) : id;
    }
    function windowShort(id) {
        const keys = {
            "5h": "ai.usage.window_short.5h",
            "week": "ai.usage.window_short.week",
            "week_opus": "ai.usage.window_short.week_opus",
            "week_sonnet": "ai.usage.window_short.week_sonnet"
        };
        return keys[id] ? I18n.t(keys[id]) : id;
    }

    Component.onCompleted: UsageService.start()
}
