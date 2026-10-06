pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
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
import qs.modules.aicenter.providers
import qs.modules.aicenter.tasks
import "../services/tasks/TaskModel.js" as TaskModel
import qs.modules.aicenter.usage

// The AI bar. Two spaces (GlobalStates.aiSpace): Assistant (any engine,
// compact transcript) and Code (CLI agents in a project: project bar,
// detailed transcript, changes, session settings). Three sizes: compact
// (overlay history), wide (history column; Code also docks the changes)
// and fullscreen (same, readable centre column). Code without an open
// session shows the task board (TaskWorkspace) and the composer creates
// tasks (TaskOptions); its chat toggle brings back the interactive agent
// chat. Sessions and drafts live in Ai; this view only presents them.
StyledRect {
    id: root
    property bool frameWrapped: false
    // The one modal overlay on top of the bar: "" (none) | history (the
    // drawer, when the history is not docked) | settings (Code session
    // settings) | usage | connect (the Connect sheet) | changes (the
    // changes drawer in narrow sizes). Opening one closes the other.
    property string overlay: ""
    readonly property bool historyOpen: overlay === "history"
    readonly property bool settingsOpen: overlay === "settings"
    readonly property bool usageOpen: overlay === "usage"
    readonly property bool changesDrawerOpen: overlay === "changes"
    property bool changesOpen: true
    readonly property bool code: GlobalStates.aiSpace === "code"
    readonly property bool wide: GlobalStates.assistantWide || GlobalStates.assistantFullscreen
    property bool codeChat: false
    readonly property bool taskMode: code && Ai.activeAgent === null && !codeChat
    readonly property string project: (Ai.agentSettings && Ai.agentSettings.cwd) || Quickshell.env("HOME")
    readonly property bool historyDocked: wide && width >= 760 && !taskMode
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
    function leaveComposer() {
        const board = workspaceLoader.item as Item;
        if (root.taskMode && board && !board.activeFocus)
            board.forceActiveFocus();
        else
            GlobalStates.hideAssistant();
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
    // Shows overlay `name` ("" closes the current one); the previous one
    // closes (the Connect sheet through its own close()). Closing every
    // overlay gives the focus back to the composer.
    function setOverlay(name) {
        const previous = overlay;
        if (previous === name)
            return;
        overlay = name;
        if (previous === "connect" && connectSheet.opened)
            connectSheet.close();
        if (name === "")
            focusComposer();
    }
    function toggleOverlay(name) {
        setOverlay(overlay === name ? "" : name);
    }
    function closeOverlay(name) {
        if (overlay === name)
            setOverlay("");
    }
    function openConnect(provider) {
        setOverlay("connect");
        connectSheet.open(provider);
    }
    function toggleHistory() {
        if (historyDocked) {
            sessionList.focusSearch();
            return;
        }
        toggleOverlay("history");
        if (historyOpen)
            drawer.focusSearch();
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
    onCodeChanged: {
        closeOverlay("settings");
        closeOverlay("changes");
    }
    // A docked column replaces its drawer.
    onHistoryDockedChanged: if (historyDocked)
        closeOverlay("history")
    onChangesDockedChanged: if (changesDocked)
        closeOverlay("changes")
    readonly property UsageStripState usageStrip: UsageStripState {}
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
        function onConnectProviderRequested(provider) {
            root.openConnect(provider);
        }
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: Ai.newConversation()
    }
    Connections {
        target: TasksService
        function onFocusRequested() {
            root.codeChat = false;
            root.closeOverlay("history");
        }
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
            usageOpen: root.usageOpen
            onUsageToggled: root.toggleOverlay("usage")
            onHistoryToggled: root.toggleHistory()
            onSettingsToggled: root.toggleOverlay("settings")
            onChangesToggled: {
                if (root.changesDocked)
                    root.changesOpen = !root.changesOpen;
                else
                    root.toggleOverlay("changes");
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
                Layout.maximumWidth: GlobalStates.assistantFullscreen && !root.taskMode ? 960 : Number.POSITIVE_INFINITY
                Layout.minimumWidth: Math.min(320, root.width - 20)
                spacing: 6
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Loader {
                        id: workspaceLoader
                        anchors.fill: parent
                        sourceComponent: root.hasConversation ? transcriptC : (root.code ? (root.codeChat ? codeEmptyC : tasksC) : welcomeC)
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
                TaskOptions {
                    id: taskOptions
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    visible: root.code && Ai.activeAgent === null
                    project: root.project
                    chat: root.codeChat
                    onChatToggled: chat => {
                        root.codeChat = chat;
                        root.focusComposer();
                    }
                    onTemplateChosen: command => composer.insert(command)
                    onRestore: (text, attachments) => {
                        composer.text = text;
                        composer.attachments = attachments;
                    }
                }
                ComposerStatus {
                    Layout.fillWidth: true
                    visible: !root.taskMode
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    contextUsed: Ai.contextState ? Ai.contextState.used : 0
                    contextWindow: Ai.contextState ? Ai.contextState.window : 0
                    contextSource: Ai.contextState ? Ai.contextState.source : ""
                    canCompact: Ai.contextState ? Ai.contextState.canCompact : false
                    compacting: Ai.contextState ? Ai.contextState.compacting : false
                    costText: root.usageStrip.costText
                    costDetail: root.usageStrip.costDetail
                    limitFraction: root.usageStrip.limitFraction
                    limitText: root.usageStrip.limitText
                    limitLevel: root.usageStrip.limitLevel
                    limitTooltip: root.usageStrip.limitTooltip
                    limitDetail: root.usageStrip.limitDetail
                    onUsageRequested: root.setOverlay("usage")
                    onPickRequested: picker.open()
                    onCompactRequested: Ai.contextState.compact(null)
                }
                Composer {
                    id: composer
                    objectName: "workspaceComposer"
                    Layout.fillWidth: true
                    busy: Ai.busy
                    placeholder: Ai.activeAgent ? I18n.t("ai.agent_followup") : (root.taskMode ? I18n.t("ai.tasks.placeholder") : (root.code ? I18n.t("ai.code_placeholder") : I18n.t("ai.ask_anything")))
                    submitHandler: (text, attachments) => root.taskMode ? taskOptions.submit(text, attachments) : root.send(text, attachments)
                    extraCommands: root.taskMode ? TaskModel.slashCommands(TasksService.templates[root.project] || []) : []
                    builtinCommands: !root.taskMode
                    onTextChanged: root.saveDraft()
                    onAttachmentsChanged: root.saveDraft()
                    onStopRequested: Ai.stop()
                    onEscapePressed: root.leaveComposer()
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
    Component {
        id: tasksC
        TaskWorkspace {
            project: root.project
            wide: root.wide
            onNewTaskRequested: root.focusComposer()
            onTemplateChosen: command => composer.insert(command)
            onEscapeRequested: GlobalStates.hideAssistant()
        }
    }

    SessionDrawer {
        id: drawer
        anchors.fill: parent
        anchors.margins: 10
        space: GlobalStates.aiSpace
        visible: root.historyOpen && !root.historyDocked
        z: 10
        onCloseRequested: root.closeOverlay("history")
    }
    ChangesPane {
        anchors.fill: parent
        anchors.margins: 10
        // In narrow sizes the changes action opens this drawer.
        visible: root.changesDrawerOpen && !root.changesDocked && root.code && Ai.activeAgent !== null
        z: 9
        diffs: root.diffs
        onCloseRequested: root.closeOverlay("changes")
    }
    AgentSettings {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: Math.min(parent.width - 20, 380)
        visible: root.settingsOpen && root.code
        z: 11
        onCloseRequested: root.closeOverlay("settings")
    }
    ConnectSheet {
        id: connectSheet
        anchors.fill: parent
        anchors.margins: 10
        z: 13
        // Closed by itself (Esc, saved) or replaced by another overlay.
        onCloseRequested: root.closeOverlay("connect")
    }
    UsageScreen {
        // Below the header, so its usage button toggles the screen.
        anchors.fill: parent
        anchors.margins: 10
        anchors.topMargin: 10 + header.height + 8
        visible: root.usageOpen
        z: 12
        onCloseRequested: root.closeOverlay("usage")
    }
    ModelPicker {
        id: picker
        parent: root
        x: (root.width - width) / 2
        y: 60
        filterKind: root.code ? "agent" : "all"
        onPicked: id => Ai.setModel(id)
        onConnectRequested: provider => Ai.openProviderSettings(provider)
        onClosed: {
            if (!connectSheet.opened)
                root.focusComposer();
        }
    }
}
