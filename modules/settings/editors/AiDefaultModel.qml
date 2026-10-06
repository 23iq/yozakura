pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.aicenter.agent
import qs.modules.settings.store
import "../../services/ai/Providers.js" as Providers

// Default engine of the Assistant (ai.defaultModel): every listed model of
// the connected providers and the CLI agents, or "last used".
ColumnLayout {
    id: root

    property var entry

    readonly property string value: SettingsStore.get("ai.defaultModel") || ""
    readonly property var choices: {
        const list = [
            {
                id: "",
                name: I18n.t("prefs.ai.default_engine.last")
            }
        ];
        for (const m of Ai.models || [])
            list.push({
                id: m.id,
                name: m.kind === "agent" ? m.name : m.name + "  ·  " + Providers.provider(m.provider).label
            });
        if (value && !list.some(c => c.id === root.value))
            list.push({
                id: root.value,
                name: root.value
            });
        return list;
    }

    Component.onCompleted: Ai._ensureInit()

    SettingsChoice {
        objectName: "defaultModelChoice"
        Layout.fillWidth: true
        model: root.choices
        currentIndex: Math.max(0, root.choices.findIndex(c => c.id === root.value))
        onActivated: SettingsStore.set("ai.defaultModel", currentValue)
    }
}
