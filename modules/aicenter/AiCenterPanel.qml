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

// One mounted workspace owns presentation; sessions and drafts live in Ai.
StyledRect {
    id: root
    property bool frameWrapped: false
    property bool historyOpen: false
    property bool settingsOpen: false
    property bool changesOpen: true
    property bool changesDrawerOpen: false
    readonly property bool wide: GlobalStates.assistantWide || GlobalStates.assistantFullscreen
    readonly property bool persistentHistory: wide && width >= 900
    readonly property bool persistentChanges: wide && width >= 1200 && Ai.activeAgent !== null
    property string draftKey: ""
    property bool restoringDraft: false
    readonly property var diffs: {
        Ai.agents ? Ai.agents.timelineRevision : 0;
        const timeline = Ai.activeAgent && Ai.agents ? Ai.agents.timeline(Ai.activeAgent.id) : null;
        return timeline ? timeline.state.diffs.slice() : [];
    }
    variant: frameWrapped ? "transparent" : "bg"
    glassSurface: "sidebars"
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
        historyOpen = !historyOpen;
        if (persistentHistory)
            sessionList.focusSearch();
        else if (historyOpen)
            drawer.focusSearch();
        else
            focusComposer();
    }
    Component.onCompleted: {
        Ai._ensureInit();
        restoreDraft();
    }
    Component.onDestruction: saveDraft()
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
        onActivated: GlobalStates.assistantWide = !GlobalStates.assistantWide
    }
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: root.focusComposer()
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
            onSettingsToggled: root.settingsOpen = !root.settingsOpen
            onChangesToggled: {
                if (root.persistentChanges)
                    root.changesOpen = !root.changesOpen;
                else
                    root.changesDrawerOpen = !root.changesDrawerOpen;
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            SessionDrawer {
                id: sessionList
                Layout.preferredWidth: Math.min(300, root.width * 0.25)
                Layout.fillHeight: true
                visible: root.persistentHistory
                onCloseRequested: root.focusComposer()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: Math.min(320, root.width - 20)
                spacing: 8
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Loader {
                        anchors.fill: parent
                        active: Ai.activeAgent === null && (!Ai.currentModel || Ai.currentModel.kind !== "agent")
                        sourceComponent: ChatView {
                            session: Ai.mode === "shell" ? Ai.shellChat : Ai.chat
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
                        active: Ai.activeAgent !== null || (Ai.currentModel && Ai.currentModel.kind === "agent")
                        sourceComponent: AgentView {
                            wide: root.persistentChanges && root.changesOpen
                            sessionId: Ai.activeAgent ? Ai.activeAgent.id : ""
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!Ai.noticeError
                    text: Ai.noticeError || ""
                    wrapMode: Text.Wrap
                    color: Colors.error
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                }
                Composer {
                    id: composer
                    objectName: "workspaceComposer"
                    Layout.fillWidth: true
                    busy: Ai.busy
                    placeholder: Ai.activeAgent ? I18n.t("ai.agent_followup") : I18n.t("ai.ask_anything")
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
                visible: root.persistentChanges && root.changesOpen
                diffs: root.diffs
                onCloseRequested: root.changesOpen = false
            }
        }
    }
    SessionDrawer {
        id: drawer
        anchors.fill: parent
        anchors.margins: 10
        visible: root.historyOpen && !root.persistentHistory
        z: 10
        onCloseRequested: {
            root.historyOpen = false;
            root.focusComposer();
        }
    }
    ChangesPane {
        anchors.fill: parent
        anchors.margins: 10
        visible: root.changesDrawerOpen && !root.persistentChanges && Ai.activeAgent !== null && root.historyOpen === false && root.settingsOpen === false
        // In narrow widths the changes action explicitly opens this drawer.
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
        visible: root.settingsOpen
        z: 11
        onCloseRequested: root.settingsOpen = false
    }
    ModelPicker {
        id: picker
        parent: root
        x: (root.width - width) / 2
        y: 60
        filterKind: "all"
        onPicked: id => Ai.setModel(id)
        onClosed: root.focusComposer()
    }
}
