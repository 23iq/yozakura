pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.settings.store
import "../../services/ai/EffortPrefs.js" as EffortPrefs

// CLI agents (own login, no API keys): availability, binary, model, YOLO,
// and the shared "safe auto, ask the rest" policy.
ColumnLayout {
    id: root

    property var entry

    spacing: 10

    readonly property var ids: ["claude", "codex", "opencode"]
    readonly property var labels: ({
            claude: "Claude Code",
            codex: "Codex",
            opencode: "OpenCode"
        })

    function info(id) {
        return Ai.agents ? Ai.agents.agents.find(a => a.id === id) : null;
    }

    function setAgent(id, key, value) {
        SettingsStore.set("ai.agents." + id + "." + key, value);
    }

    AiToggleRow {
        label: I18n.t("ai.auto_approve_reads")
        checked: (Config.ai.agents.autoApprove || []).indexOf("read") >= 0
        onToggled: v => SettingsStore.set("ai.agents.autoApprove", v ? ["read"] : [])
    }

    Repeater {
        model: root.ids
        delegate: StyledRect {
            id: card
            required property string modelData
            readonly property var meta: root.info(modelData)
            readonly property var cfg: Config.ai.agents[modelData] || ({})
            // Native effort levels of the configured model (agents.models).
            readonly property var efforts: {
                Ai.agents ? Ai.agents.modelCatalogs.catalogs : null;
                return Ai.agents ? EffortPrefs.agentLevels(Ai.agents.settingsFor(modelData, ""), cfg.model || "") : [];
            }
            Component.onCompleted: if (Ai.agents && meta && meta.available && !Ai.agents.modelCatalogs.has(modelData, ""))
                Ai.agents.refreshModels(modelData, "")
            Layout.fillWidth: true
            variant: "common"
            radius: Styling.radius(-2)
            implicitHeight: agentCol.implicitHeight + 20

            ColumnLayout {
                id: agentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StatusDot {
                        status: card.meta && card.meta.available ? "idle" : "exited"
                    }
                    Text {
                        text: root.labels[card.modelData]
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.DemiBold
                        color: Colors.overSurface
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.meta ? (card.meta.available ? (card.meta.version || card.meta.binary) : I18n.t("ai.not_installed")) : "…"
                        elide: Text.ElideRight
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-3)
                        color: Colors.outline
                    }
                }
                AiToggleRow {
                    label: I18n.t("ai.enabled")
                    checked: card.cfg.enabled
                    onToggled: v => root.setAgent(card.modelData, "enabled", v)
                }
                AiToggleRow {
                    label: I18n.t("ai.yolo_label")
                    checked: card.cfg.yolo
                    onToggled: v => root.setAgent(card.modelData, "yolo", v)
                }
                AiTextRow {
                    label: I18n.t("ai.binary_path")
                    value: card.cfg.binary
                    placeholder: card.meta && card.meta.binary ? card.meta.binary : card.modelData
                    mono: true
                    onEdited: t => root.setAgent(card.modelData, "binary", t.trim())
                }
                AiTextRow {
                    label: I18n.t("ai.agent_model")
                    value: card.cfg.model
                    placeholder: I18n.t("ai.agent_model_hint")
                    mono: true
                    onEdited: t => root.setAgent(card.modelData, "model", t.trim())
                }
                AiSelectRow {
                    visible: card.efforts.length > 0
                    label: I18n.t("ai.effort")
                    options: [
                        {
                            value: "",
                            label: "ai.model_default"
                        }
                    ].concat(card.efforts.map(e => ({
                                value: e,
                                label: "ai.effort_level." + e
                            })))
                    value: card.cfg.effort || ""
                    onSelected: v => root.setAgent(card.modelData, "effort", v)
                }
                AiTextRow {
                    visible: card.efforts.length === 0
                    label: I18n.t("ai.effort")
                    value: card.cfg.effort || ""
                    placeholder: I18n.t("ai.model_default")
                    mono: true
                    onEdited: t => root.setAgent(card.modelData, "effort", t.trim())
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("ai.perm_note_" + card.modelData)
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }
            }
        }
    }

    Component.onCompleted: Ai._ensureInit()
}
