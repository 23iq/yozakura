pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common
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
    radius: Styling.radius(-2)

    function refresh() {
        if (isAgent && Ai.agents)
            Ai.agents.refreshModels(settings.agent, settings.cwd);
    }
    Component.onCompleted: refresh()
    onSettingsChanged: refresh()

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("ai.session_settings")
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                }
                IconButton {
                    glyph: Icons.cancel
                    tooltip: I18n.t("ai.close")
                    onClicked: root.closeRequested()
                }
            }
            Text {
                Layout.fillWidth: true
                visible: Ai.busy
                wrapMode: Text.Wrap
                text: I18n.t("ai.settings_busy")
                color: Colors.outline
                font.pixelSize: Styling.fontSize(-2)
            }
            Chip {
                label: I18n.t("ai.engine_default")
                glyph: Icons.pin
                enabled: !!Ai.currentModel && Ai.currentModel.available !== false
                onClicked: Ai.setDefaultModel(Ai.currentModel.id)
            }
            Text {
                visible: root.isAgent
                text: I18n.t("ai.choose_model")
                color: Colors.outline
                font.pixelSize: Styling.fontSize(-2)
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
                    radius: Styling.radius(-4)
                }
                onEditingFinished: Ai.configureAgent({
                    model: text,
                    effort: ""
                })
            }
            Text {
                visible: root.efforts.length > 0
                text: I18n.t("ai.effort")
                color: Colors.outline
                font.pixelSize: Styling.fontSize(-2)
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
                glyph: Icons.clockCounterClockwise
                label: I18n.t("ai.retry_models")
                onClicked: root.refresh()
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.catalog.error
                text: root.catalog.error || ""
                wrapMode: Text.Wrap
                color: Colors.error
                font.pixelSize: Styling.fontSize(-2)
            }
            Text {
                visible: root.isAgent
                text: I18n.t("ai.agent_folder")
                color: Colors.outline
                font.pixelSize: Styling.fontSize(-2)
            }
            TextField {
                Layout.fillWidth: true
                visible: root.isAgent
                text: root.settings.cwd || ""
                readOnly: Ai.activeAgent !== null
                color: Colors.overSurface
                background: StyledRect {
                    variant: "common"
                    radius: Styling.radius(-4)
                }
                onEditingFinished: Ai.configureAgent({
                    cwd: text
                })
            }
            // The project of the Code space; changing it opens a new session there.
            Chip {
                objectName: "settingsBrowse"
                glyph: Icons.folderOpen
                label: I18n.t("ai.browse")
                visible: root.isAgent
                onClicked: root.browseRequested()
            }
            Switch {
                id: approvalSwitch
                Layout.fillWidth: true
                visible: root.isAgent
                enabled: !Ai.busy
                checked: root.settings.yolo === true
                onToggled: Ai.configureAgent({
                    yolo: checked
                })
                contentItem: Text {
                    text: I18n.t("ai.yolo_label")
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    wrapMode: Text.Wrap
                    leftPadding: 54
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: StyledRect {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 24
                    variant: approvalSwitch.checked ? "primary" : "common"
                    radius: Styling.radius(-4)
                    border.width: 1
                    border.color: Colors.outlineVariant
                    StyledRect {
                        x: approvalSwitch.checked ? 23 : 3
                        y: 3
                        width: 18
                        height: 18
                        variant: "focus"
                        radius: Styling.radius(-6)
                    }
                }
            }
            Text {
                visible: root.isAgent
                text: I18n.t("ai.system_prompt")
                color: Colors.outline
                font.pixelSize: Styling.fontSize(-2)
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
                    radius: Styling.radius(-4)
                }
                onActiveFocusChanged: if (!activeFocus && text !== (root.settings.systemPrompt || ""))
                    Ai.configureAgent({
                        systemPrompt: text
                    })
            }
        }
    }
}
