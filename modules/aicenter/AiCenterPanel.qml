pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.header
import qs.modules.aicenter.transcript
import qs.modules.aicenter.assistant
import qs.modules.aicenter.code
import qs.modules.aicenter.agent
import qs.modules.aicenter.composer
import qs.modules.aicenter.sessions

// The AI bar. Two spaces (GlobalStates.aiSpace): Assistant (any engine,
// compact transcript) and Code (CLI agents in a project: project bar,
// detailed transcript, changes, session settings). Three sizes: compact
// (overlay history), wide (history column; Code also docks the changes)
// and fullscreen (same, readable centre column). Sessions and drafts live
// in Ai; this view only presents them.
StyledRect {
    id: root
    property bool frameWrapped: false
    property bool historyOpen: false
    property bool settingsOpen: false
    property bool changesOpen: true
    property bool changesDrawerOpen: false
    readonly property bool code: GlobalStates.aiSpace === "code"
    readonly property bool wide: GlobalStates.assistantWide || GlobalStates.assistantFullscreen
    readonly property bool historyDocked: wide && width >= 760
    readonly property bool changesDocked: code && wide && width >= 1100 && Ai.activeAgent !== null
    readonly property bool hasConversation: Ai.activeAgent !== null || (Ai.mode !== "agent" && Ai.activeChat !== null && Ai.activeChat.rows.count > 0)
    property string draftKey: ""
    property bool restoringDraft: false
    readonly property var diffs: {
        Ai.agents ? Ai.agents.timelineRevision : 0;
        const timeline = Ai.activeAgent && Ai.agents ? Ai.agents.timeline(Ai.activeAgent.id) : null;
        return timeline ? timeline.state.diffs.slice() : [];
    }
    variant: frameWrapped ? "transparent" : "bg"
    glassSurface: Config.ai.appearance.glass === false ? "" : "sidebars"
    backgroundOpacity: Config.ai.appearance.opacity < 1 ? Config.ai.appearance.opacity : -1
    radius: frameWrapped ? 0 : Styling.radius(0)

    function focusComposer() {
        composer.focusInput();
    }
    function saveDraft() {
        if (!restoringDraft && draftKey && Ai.drafts)
            Ai.drafts.setDraft(draftKey, composer.text, composer.attachments);
    }
    function restoreDraft() {
        saveDraft();
        restoringDraft = true;
        draftKey = Ai.sessionKey;
        const draft = Ai.drafts ? Ai.drafts.draft(draftKey) : null;
        composer.text = draft ? draft.text || "" : "";
        composer.attachments = draft ? draft.attachments || [] : [];
        restoringDraft = false;
    }
    function send(text, attachments) {
        const key = draftKey;
        if (Ai.send(text, attachments) === false)
            return false;
        if (Ai.drafts) {
            Ai.drafts.setDraft(key, "", []);
            Ai.drafts.setDraft(Ai.sessionKey, "", []);
        }
        return true;
    }
    function toggleHistory() {
        if (historyDocked) {
            sessionList.focusSearch();
            return;
        }
        historyOpen = !historyOpen;
        if (historyOpen)
            drawer.focusSearch();
        else
            focusComposer();
    }
    function useSuggestion(text, context) {
        if (context)
            composer.addContext(context);
        composer.text = text;
        focusComposer();
    }
    Component.onCompleted: {
        Ai._ensureInit();
        restoreDraft();
    }
    Component.onDestruction: saveDraft()
    onCodeChanged: settingsOpen = false
    Connections {
        target: Ai
        function onSessionKeyChanged() {
            root.restoreDraft();
        }
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
        onActivated: header.cycleSize()
    }
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: root.focusComposer()
    }
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: Ai.setSpace("assistant")
    }
    Shortcut {
        sequence: "Ctrl+2"
        onActivated: Ai.setSpace("code")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        CenterHeader {
            id: header
            Layout.fillWidth: true
            historyOpen: root.historyOpen
            historyPinned: root.historyDocked
            settingsOpen: root.settingsOpen
            showChanges: root.code && Ai.activeAgent !== null && root.diffs.length > 0
            onHistoryToggled: root.toggleHistory()
            onSettingsToggled: root.settingsOpen = !root.settingsOpen
            onChangesToggled: {
                if (root.changesDocked)
                    root.changesOpen = !root.changesOpen;
                else
                    root.changesDrawerOpen = !root.changesDrawerOpen;
            }
        }
        ProjectBar {
            Layout.fillWidth: true
            visible: root.code
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            SessionDrawer {
                id: sessionList
                docked: true
                space: GlobalStates.aiSpace
                Layout.preferredWidth: root.historyDocked ? Math.min(300, root.width * 0.24) : 0
                Layout.fillHeight: true
                visible: Layout.preferredWidth > 1
                opacity: root.historyDocked ? 1 : 0
                Behavior on Layout.preferredWidth {
                    enabled: BarLook.animDuration > 0
                    NumberAnimation {
                        duration: BarLook.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    enabled: BarLook.animDuration > 0
                    NumberAnimation {
                        duration: BarLook.animDuration / 2
                    }
                }
                onCloseRequested: root.focusComposer()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: GlobalStates.assistantFullscreen ? 960 : Number.POSITIVE_INFINITY
                Layout.minimumWidth: Math.min(320, root.width - 20)
                spacing: 6
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Loader {
                        anchors.fill: parent
                        sourceComponent: root.hasConversation ? transcriptC : (root.code ? codeEmptyC : welcomeC)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!Ai.noticeError
                    text: Ai.noticeError || ""
                    wrapMode: Text.Wrap
                    color: Colors.error
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                }
                ContextNotice {
                    Layout.fillWidth: true
                    used: Ai.contextState ? Ai.contextState.used : 0
                    window: Ai.contextState ? Ai.contextState.window : 0
                    agent: Ai.contextState ? Ai.contextState.agentEngine : false
                    canCompact: Ai.contextState ? Ai.contextState.canCompact : false
                    compacting: Ai.contextState ? Ai.contextState.compacting : false
                    sessionKey: Ai.sessionKey
                    onCompactRequested: Ai.contextState.compact(null)
                }
                ComposerStatus {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    contextUsed: Ai.contextState ? Ai.contextState.used : 0
                    contextWindow: Ai.contextState ? Ai.contextState.window : 0
                    contextSource: Ai.contextState ? Ai.contextState.source : ""
                    canCompact: Ai.contextState ? Ai.contextState.canCompact : false
                    compacting: Ai.contextState ? Ai.contextState.compacting : false
                    onPickRequested: picker.open()
                    onCompactRequested: Ai.contextState.compact(null)
                }
                Composer {
                    id: composer
                    objectName: "workspaceComposer"
                    Layout.fillWidth: true
                    busy: Ai.busy
                    placeholder: Ai.activeAgent ? I18n.t("ai.agent_followup") : (root.code ? I18n.t("ai.code_placeholder") : I18n.t("ai.ask_anything"))
                    submitHandler: (text, attachments) => root.send(text, attachments)
                    onTextChanged: root.saveDraft()
                    onAttachmentsChanged: root.saveDraft()
                    onStopRequested: Ai.stop()
                    onEscapePressed: GlobalStates.hideAssistant()
                }
            }
            ChangesPane {
                Layout.preferredWidth: Math.min(420, root.width * 0.3)
                Layout.fillHeight: true
                visible: root.changesDocked && root.changesOpen
                diffs: root.diffs
                onCloseRequested: root.changesOpen = false
            }
        }
    }

    Component {
        id: transcriptC
        TranscriptView {
            style: root.code ? "detailed" : "compact"
            agentId: Ai.activeAgent ? Ai.activeAgent.id : ""
            session: Ai.activeAgent ? null : Ai.activeChat
            agentLabel: Ai.currentModel ? Ai.currentModel.name : ""
        }
    }
    Component {
        id: welcomeC
        WelcomeView {
            maxSuggestions: root.wide ? 6 : 4
            onSuggestion: (text, context) => root.useSuggestion(text, context)
            onConnectRequested: Ai.openProviderSettings()
        }
    }
    Component {
        id: codeEmptyC
        CodeEmpty {}
    }

    SessionDrawer {
        id: drawer
        anchors.fill: parent
        anchors.margins: 10
        space: GlobalStates.aiSpace
        visible: root.historyOpen && !root.historyDocked
        z: 10
        onCloseRequested: {
            root.historyOpen = false;
            root.focusComposer();
        }
    }
    ChangesPane {
        anchors.fill: parent
        anchors.margins: 10
        // In narrow sizes the changes action opens this drawer.
        visible: root.changesDrawerOpen && !root.changesDocked && root.code && Ai.activeAgent !== null && !root.historyOpen && !root.settingsOpen
        z: 9
        diffs: root.diffs
        onCloseRequested: root.changesDrawerOpen = false
    }
    AgentSettings {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: Math.min(parent.width - 20, 380)
        visible: root.settingsOpen && root.code
        z: 11
        onCloseRequested: root.settingsOpen = false
    }
    ModelPicker {
        id: picker
        parent: root
        x: (root.width - width) / 2
        y: 60
        filterKind: root.code ? "agent" : "all"
        onPicked: id => Ai.setModel(id)
        onConnectRequested: provider => Ai.openProviderSettings(provider)
        onClosed: root.focusComposer()
    }
}
