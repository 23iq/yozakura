import QtQuick
import qs.modules.theme
import qs.modules.services

// "Ask AI" row: sends the query to the AI center quick ask (notch card).
// Last in mixed searches; the "?" prefix or Tab (prefix.launcher.aiOnTab)
// sends directly.
LauncherProvider {
    id: ai

    mixedLimit: 1

    function compute(text, searchMode) {
        if (!Ai.enabled)
            return [];
        const q = (text || "").trim();
        if (q === "")
            return searchMode === "prefix" ? [
                {
                    "key": "hint",
                    "title": I18n.t("launcher.ai.hint"),
                    "subtitle": I18n.t("launcher.ai.hint.desc"),
                    "icon": Icons.sparkle,
                    "inert": true
                }
            ] : [];
        const model = Ai.quickModel ? Ai.quickModel.name : "";
        return [
            {
                "key": "ask",
                "title": q,
                "subtitle": I18n.t("launcher.ai.ask") + (model ? "  ·  " + model : ""),
                "icon": Icons.sparkle,
                "badge": I18n.t("launcher.provider.ai"),
                "hint": I18n.t("launcher.ai.send"),
                "data": {
                    "text": q
                }
            }
        ];
    }

    // The launcher closes first, then the quick-ask card opens in the notch.
    function ask(text) {
        const q = (text || "").trim();
        if (q === "" || !Ai.enabled)
            return false;
        Qt.callLater(() => Ai.askQuick(q));
        return true;
    }

    function activate(item, option) {
        if (item.inert || !item.data)
            return false;
        return ai.ask(item.data.text);
    }
}
