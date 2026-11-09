pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common
import qs.modules.components.kit
import qs.config

// Edits apply only to the selected session, or to its pending launch.
StyledRect {
    id: root
    signal closeRequested
    signal browseRequested
    readonly property var settings: Ai.agentSettings || ({})
    readonly property bool isAgent: Ai.currentModel && Ai.currentModel.kind === "agent"
    readonly property var catalog: isAgent && Ai.agents ? Ai.agents.settingsFor(settings.agent, settings.cwd) : ({
            models: []
        })
    readonly property var models: catalog.models || []
    readonly property var selectedModel: models.find(m => settings.model ? m.id === settings.model : m.isDefault === true) || null
    readonly property var efforts: selectedModel ? (selectedModel.efforts || []) : []
    // "Engine default · Opus 5.5": what the default resolves to.
    readonly property var defaultModel: models.find(m => m.isDefault === true) || null
    readonly property string defaultModelName: defaultModel ? (defaultModel.resolved || defaultModel.name || defaultModel.id) : ""
    readonly property string defaultEffort: selectedModel ? selectedModel.defaultEffort || "" : ""
    // Opaque: it covers the transcript.
    variant: "bg"
    enableShadow: true
    radius: Look.radius("control")

    function refresh() {
        if (isAgent && Ai.agents)
            Ai.agents.refreshModels(settings.agent, settings.cwd);
    }
    Component.onCompleted: refresh()
    onSettingsChanged: refresh()

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: Space.m
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: Space.s
            RowLayout {
                Layout.fillWidth: true
                KitText {
                    Layout.fillWidth: true
                    text: I18n.t("ai.session_settings")
                }
                IconButton {
                    size: "xs"
                    icon: Icons.cancel
                    tooltip: I18n.t("ai.close")
                    onClicked: root.closeRequested()
                }
            }
            KitText {
                role: "caption"
                Layout.fillWidth: true
                visible: Ai.busy
                wrapMode: Text.Wrap
                text: I18n.t("ai.settings_busy")
            }
            Chip {
                text: I18n.t("ai.engine_default")
                icon: Icons.pin
                enabled: !!Ai.currentModel && Ai.currentModel.available !== false
                onClicked: Ai.setDefaultModel(Ai.currentModel.id)
            }
            KitText {
                role: "caption"
                visible: root.isAgent
                text: I18n.t("ai.choose_model")
            }
            SettingsChoice {
                Layout.fillWidth: true
                visible: root.isAgent
                enabled: !Ai.busy
                model: [
                    {
                        id: "",
                        name: I18n.t("ai.model_default") + (root.defaultModelName ? " · " + root.defaultModelName : "")
                    }
                ].concat(root.models)
                currentIndex: Math.max(0, model.findIndex(m => m.id === (root.settings.model || "")))
                onActivated: Ai.configureAgent({
                    model: currentValue,
                    effort: ""
                })
            }
            TextField {
                Layout.fillWidth: true
                visible: root.isAgent && root.catalog.manualModel === true
                enabled: !Ai.busy
                text: root.settings.model || ""
                placeholderText: I18n.t("ai.manual_model")
                color: Colors.overSurface
                background: StyledRect {
                    variant: "common"
                    radius: Look.radius("control")
                }
                onEditingFinished: Ai.configureAgent({
                    model: text,
                    effort: ""
                })
            }
            KitText {
                role: "caption"
                visible: root.efforts.length > 0
                text: I18n.t("ai.effort")
            }
            SettingsChoice {
                Layout.fillWidth: true
                objectName: "workspaceEffortChoice"
                visible: root.efforts.length > 0
                enabled: !Ai.busy
                model: [
                    {
                        id: "",
                        name: I18n.t("ai.model_default") + (root.defaultEffort ? " · " + root.defaultEffort : "")
                    }
                ].concat(root.efforts.map(e => ({
                            id: e,
                            name: e
                        })))
                currentIndex: Math.max(0, model.findIndex(e => e.id === (root.settings.effort || "")))
                onActivated: Ai.configureAgent({
                    effort: currentValue
                })
            }
            Chip {
                visible: root.isAgent
                icon: Icons.clockCounterClockwise
                text: I18n.t("ai.retry_models")
                onClicked: root.refresh()
            }
            KitText {
                role: "caption"
                Layout.fillWidth: true
                visible: !!root.catalog.error
                text: root.catalog.error || ""
                wrapMode: Text.Wrap
                color: Type.danger
            }
            KitText {
                role: "caption"
                visible: root.isAgent
                text: I18n.t("ai.agent_folder")
            }
            TextField {
                Layout.fillWidth: true
                visible: root.isAgent
                text: root.settings.cwd || ""
                readOnly: Ai.activeAgent !== null
                color: Colors.overSurface
                background: StyledRect {
                    variant: "common"
                    radius: Look.radius("control")
                }
                onEditingFinished: Ai.configureAgent({
                    cwd: text
                })
            }
            // The project of the Code space; changing it opens a new session there.
            Chip {
                objectName: "settingsBrowse"
                icon: Icons.folderOpen
                text: I18n.t("ai.browse")
                visible: root.isAgent
                onClicked: root.browseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.isAgent
                spacing: Space.s
                Switch {
                    id: approvalSwitch
                    enabled: !Ai.busy
                    checked: root.settings.yolo === true
                    onToggled: value => Ai.configureAgent({
                            yolo: value
                        })
                }
                KitText {
                    Layout.fillWidth: true
                    role: "caption"
                    text: I18n.t("ai.yolo_label")
                    color: Type.text
                    wrapMode: Text.Wrap
                    TapHandler {
                        onTapped: approvalSwitch.flip()
                    }
                }
            }
            KitText {
                role: "caption"
                visible: root.isAgent
                text: I18n.t("ai.system_prompt")
            }
            TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                visible: root.isAgent
                enabled: !Ai.busy
                text: root.settings.systemPrompt || ""
                color: Colors.overSurface
                wrapMode: TextArea.Wrap
                background: StyledRect {
                    variant: "common"
                    radius: Look.radius("control")
                }
                onActiveFocusChanged: if (!activeFocus && text !== (root.settings.systemPrompt || ""))
                    Ai.configureAgent({
                        systemPrompt: text
                    })
            }
        }
    }
}
