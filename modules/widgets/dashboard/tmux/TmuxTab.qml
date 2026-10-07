import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.config
import qs.modules.theme
import qs.modules.components.kit
import "TmuxModel.js" as TmuxModel

// Tmux session manager tab (dashboard and launcher prefix). Holds the tab
// state and its actions; the pieces live next to it:
//   TmuxSearchField   search + keyboard flow
//   TmuxSessionList   kit ListRows (TmuxSessionDelegate, TmuxSessionGestures,
//                     TmuxSessionOptions), click-outside
//   TmuxPreviewPanel  pane layout (TmuxPanesPreview) + windows (TmuxWindowsBar)
//   TmuxProcesses     tmux invocations; TmuxModel.js parsers/commands
Item {
    id: root
    focus: true

    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property var tmuxSessions: []
    property var filteredSessions: []

    // List model
    ListModel {
        id: sessionsModel
    }

    // Delete mode state
    property bool deleteMode: false
    property string sessionToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0 // 0 = cancel, 1 = confirm

    // Rename mode state
    property bool renameMode: false
    property string sessionToRename: ""
    property string newSessionName: ""
    property int renameSelectedIndex: -1
    property int renameButtonIndex: 0 // 0 = cancel, 1 = confirm
    property string pendingRenamedSession: "" // Track session to select after rename

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false
    property bool isFiltering: false

    // Session preview state
    property var sessionWindows: []
    property var sessionPanes: []
    property bool loadingSessionInfo: false

    // Refresh tmux sessions when tab becomes visible
    onVisibleChanged: {
        if (visible) {
            refreshTmuxSessions();
        }
    }

    function adjustScrollForExpandedItem(index) {
        resultsList.adjustScrollForExpandedItem(index);
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && resultsList.count > 0) {
            resultsList.positionViewAtIndex(0, ListView.Beginning);
        }

        // Close expanded options when selection changes to a different item
        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }

        // Load session info when selection changes
        if (selectedIndex >= 0 && selectedIndex < filteredSessions.length) {
            let session = filteredSessions[selectedIndex];
            if (session && !TmuxModel.isCreateRow(session)) {
                loadSessionInfo(session.name);
            } else {
                sessionWindows = [];
                sessionPanes = [];
            }
        } else {
            sessionWindows = [];
            sessionPanes = [];
        }
    }

    onSearchTextChanged: {
        updateFilteredSessions();
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        searchInput.focusInput();
        updateFilteredSessions();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function cancelDeleteModeFromExternal() {
        if (deleteMode) {
            console.log("DEBUG: Canceling delete mode from external source (tab change)");
            cancelDeleteMode();
        }
        if (renameMode) {
            console.log("DEBUG: Canceling rename mode from external source (tab change)");
            cancelRenameMode();
        }
    }

    function updateFilteredSessions() {
        var newFilteredSessions = TmuxModel.buildSessionList(tmuxSessions, searchText, !deleteMode && !renameMode);

        filteredSessions = newFilteredSessions;
        resultsList.enableScrollAnimation = false;
        resultsList.contentY = 0;

        sessionsModel.clear();
        for (var i = 0; i < newFilteredSessions.length; i++) {
            sessionsModel.append(TmuxModel.modelRow(newFilteredSessions[i]));
        }

        Qt.callLater(() => {
            resultsList.enableScrollAnimation = true;
        });

        if (!deleteMode && !renameMode) {
            if (searchText.length > 0 && newFilteredSessions.length > 0) {
                selectedIndex = 0;
                resultsList.currentIndex = 0;
            } else if (searchText.length === 0) {
                selectedIndex = -1;
                resultsList.currentIndex = -1;
            }
        }

        if (pendingRenamedSession !== "") {
            for (let i = 0; i < newFilteredSessions.length; i++) {
                if (newFilteredSessions[i].name === pendingRenamedSession) {
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    pendingRenamedSession = "";
                    break;
                }
            }
            if (pendingRenamedSession !== "") {
                pendingRenamedSession = "";
            }
        }
    }

    function enterDeleteMode(sessionName) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        sessionToDelete = sessionName;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        sessionToDelete = "";
        deleteButtonIndex = 0;
        searchInput.focusInput();
        updateFilteredSessions();
        selectedIndex = originalSelectedIndex;
        resultsList.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteSession() {
        tmux.killSession(sessionToDelete);
        cancelDeleteMode();
    }

    function enterRenameMode(sessionName) {
        renameSelectedIndex = selectedIndex;
        renameMode = true;
        sessionToRename = sessionName;
        newSessionName = sessionName;
        renameButtonIndex = 1;
        root.forceActiveFocus();
    }

    function cancelRenameMode() {
        renameMode = false;
        sessionToRename = "";
        newSessionName = "";
        renameButtonIndex = 1;
        if (pendingRenamedSession === "") {
            searchInput.focusInput();
            updateFilteredSessions();
            selectedIndex = renameSelectedIndex;
            resultsList.currentIndex = renameSelectedIndex;
        } else {
            searchInput.focusInput();
        }
        renameSelectedIndex = -1;
    }

    function confirmRenameSession() {
        if (newSessionName.trim() !== "" && newSessionName !== sessionToRename) {
            tmux.renameSession(sessionToRename, newSessionName.trim());
        } else {
            cancelRenameMode();
        }
    }

    function refreshTmuxSessions() {
        tmux.listSessions();
    }

    function loadSessionInfo(sessionName) {
        if (!sessionName)
            return;
        loadingSessionInfo = true;
        sessionWindows = [];
        sessionPanes = [];
        tmux.loadSessionInfo(sessionName);
    }

    function stripAnsiCodes(text) {
        // Remove ANSI escape sequences (CSI sequences)
        return text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\x1b\][0-9;]*;[^\x07]*\x07/g, '').replace(/\x1b[=>]/g, '');
    }

    function createTmuxSession(sessionName) {
        TerminalService.execDetached(TmuxModel.newSessionShell(sessionName));
        root.refreshTmuxSessions();
        // Close the dashboard
        Visibilities.setActiveModule("");
    }

    function attachToSession(sessionName) {
        TerminalService.execDetached(TmuxModel.attachShell(sessionName));
    }

    function switchToWindow(sessionName, windowIndex) {
        if (!sessionName || windowIndex === undefined)
            return;
        tmux.selectWindow(sessionName, windowIndex);
    }

    function focusPane(sessionName, paneIndex) {
        if (!sessionName || paneIndex === undefined)
            return;
        tmux.selectPane(sessionName, paneIndex);
    }

    implicitWidth: 400
    implicitHeight: 392

    MouseArea {
        anchors.fill: parent
        enabled: root.deleteMode || root.renameMode
        z: -10

        onClicked: {
            if (root.deleteMode) {
                root.cancelDeleteMode();
            } else if (root.renameMode) {
                root.cancelRenameMode();
            }
        }
    }

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    TmuxProcesses {
        id: tmux
        tab: root
    }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: Space.l

        // Left column: search, section label, sessions
        Item {
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true

            TmuxSearchField {
                id: searchInput
                width: parent.width
                anchors.top: parent.top
                tab: root
                list: resultsList
                text: root.searchText
                placeholderText: I18n.t("tmux.search")
                iconText: ""
                prefixIcon: root.prefixIcon
            }

            SectionLabel {
                id: sessionsLabel
                anchors.top: searchInput.bottom
                anchors.topMargin: Space.l
                x: Space.s
                width: parent.width - Space.s * 2
                text: I18n.t("tmux.sessions")
            }

            TmuxSessionList {
                id: resultsList
                width: parent.width
                anchors.top: sessionsLabel.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Space.s
                tab: root
                model: sessionsModel
            }
        }

        Divider {
            vertical: true
            Layout.fillHeight: true
        }

        TmuxPreviewPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            tab: root
        }
    }

    Component.onCompleted: {
        refreshTmuxSessions();
        Qt.callLater(() => {
            focusSearchInput();
        });
    }

    Keys.onPressed: event => {
        if (root.deleteMode) {
            if (event.key === Qt.Key_Left) {
                root.deleteButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.deleteButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.deleteButtonIndex === 0) {
                    root.cancelDeleteMode();
                } else {
                    root.confirmDeleteSession();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.renameMode) {
            if (event.key === Qt.Key_Left) {
                root.renameButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.renameButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.renameButtonIndex === 0) {
                    root.cancelRenameMode();
                } else {
                    root.confirmRenameSession();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelRenameMode();
                event.accepted = true;
            }
        }
    }
}
