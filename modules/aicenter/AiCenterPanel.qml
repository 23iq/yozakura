pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.header
import qs.modules.aicenter.chat
import qs.modules.aicenter.agent
import qs.modules.aicenter.composer
import qs.modules.aicenter.sessions

// AI center content: header, mode body (chat / agent / shell), composer and
// the history drawer. Conversation state lives in the Ai service, so this
// item can be unloaded and recreated freely.
StyledRect {
    id: root

    property bool frameWrapped: false
    property bool historyOpen: false
    readonly property bool wide: GlobalStates.assistantWide
    readonly property string shellAgent: Config.ai.shell.target.indexOf("agent:") === 0 ? Config.ai.shell.target.substring(6) : ""
    readonly property var shellAgentSession: shellAgent && Ai.agents ? (Ai.agents.sessions.find(s => s.mode === "shell" && s.agent === shellAgent) || null) : null
    readonly property bool composerBusy: Ai.mode === "agent" ? (Ai.agents && Ai.agents.active ? ["running", "starting", "waiting"].indexOf(Ai.agents.active.status) >= 0 : false) : Ai.busy

    variant: frameWrapped ? "transparent" : "bg"
    glassSurface: "sidebars"
    radius: frameWrapped ? 0 : (variantConfig.radius !== undefined ? variantConfig.radius : Styling.radius(0))

    function focusComposer() {
        composer.focusInput();
    }

    function send(text, attachments) {
        Ai.send(text, attachments);
    }

    Component.onCompleted: Ai._ensureInit()

    Connections {
        target: Ai
        function onModelSelectionRequested() {
            picker.open();
        }
        function onFocusComposerRequested() {
            root.focusComposer();
        }
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: Ai.newConversation()
    }
    Shortcut {
        sequence: "Ctrl+K"
        onActivated: picker.open()
    }
    Shortcut {
        sequence: "Ctrl+H"
        onActivated: root.toggleHistory()
    }
    Shortcut {
        sequence: "Ctrl+W"
        onActivated: GlobalStates.assistantWide = !GlobalStates.assistantWide
    }
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: root.focusComposer()
    }
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: Ai.setMode("chat")
    }
    Shortcut {
        sequence: "Ctrl+2"
        onActivated: Ai.setMode("agent")
    }
    Shortcut {
        sequence: "Ctrl+3"
        onActivated: Ai.setMode("shell")
    }

    function toggleHistory() {
        historyOpen = !historyOpen;
        if (historyOpen)
            drawer.focusSearch();
        else
            focusComposer();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        CenterHeader {
            Layout.fillWidth: true
            historyOpen: root.historyOpen
            onHistoryToggled: root.toggleHistory()
            onPickModel: picker.open()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: body
                anchors.fill: parent
                // Kept alive under the history drawer so scroll state survives.
                opacity: root.historyOpen ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 3
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: Ai.mode === "chat"
                    sourceComponent: ChatView {
                        session: Ai.chat
                        mode: "chat"
                        onSuggestion: (text, context) => {
                            if (context)
                                composer.addContext(context);
                            composer.text = text;
                            root.focusComposer();
                        }
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: Ai.mode === "shell" && root.shellAgentSession === null
                    sourceComponent: ChatView {
                        session: Ai.shellChat
                        mode: "shell"
                        onSuggestion: text => root.send(text, [])
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: Ai.mode === "shell" && root.shellAgentSession !== null
                    sourceComponent: AgentView {
                        sessionId: root.shellAgentSession ? root.shellAgentSession.id : ""
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: Ai.mode === "agent"
                    sourceComponent: AgentView {
                        wide: root.wide
                    }
                }
            }

            SessionDrawer {
                id: drawer
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.historyOpen ? 1 : 0
                scale: root.historyOpen ? 1 : 0.97
                z: 10
                onCloseRequested: {
                    root.historyOpen = false;
                    root.focusComposer();
                }
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 3
                    }
                }
                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 3
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Composer {
            id: composer
            Layout.fillWidth: true
            busy: root.composerBusy
            placeholder: Ai.mode === "agent" ? (Ai.agents && Ai.agents.active ? I18n.t("ai.agent_followup") : I18n.t("ai.agent_first")) : (Ai.mode === "shell" ? I18n.t("ai.shell_placeholder") : I18n.t("ai.ask_anything"))
            onSubmitted: (text, attachments) => root.send(text, attachments)
            onStopRequested: Ai.stop()
            onEscapePressed: GlobalStates.hideAssistant()
        }
    }

    ModelPicker {
        id: picker
        parent: root
        x: (root.width - width) / 2
        y: 90
        filterKind: Ai.mode === "agent" ? "agent" : "chat"
        onPicked: id => Ai.setModel(id)
        onClosed: root.focusComposer()
    }
}
