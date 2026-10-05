import QtQuick
import Quickshell.Io
import "TmuxModel.js" as TmuxModel

// tmux invocations of the tmux tab: listing sessions, the selected
// session's windows and panes, and kill/rename/select commands. Results are
// written back to `tab` (TmuxTab) exactly as the tab used to do inline.
Item {
    id: procs

    required property var tab

    function listSessions() {
        tmuxProcess.running = true;
    }

    function killSession(session) {
        killProcess.command = TmuxModel.killCommand(session);
        killProcess.running = true;
    }

    function renameSession(session, newName) {
        renameProcess.command = TmuxModel.renameCommand(session, newName);
        renameProcess.running = true;
    }

    function loadSessionInfo(session) {
        windowsProcess.command = TmuxModel.listWindowsCommand(session);
        windowsProcess.running = true;
        panesProcess.command = TmuxModel.listPanesCommand(session);
        panesProcess.running = true;
    }

    function selectWindow(session, windowIndex) {
        switchWindowProcess.command = TmuxModel.selectWindowCommand(session, windowIndex);
        switchWindowProcess.running = true;
    }

    function selectPane(session, paneIndex) {
        focusPaneProcess.command = TmuxModel.selectPaneCommand(session, paneIndex);
        focusPaneProcess.running = true;
    }

    // Reload the preview of the selected session (active window/pane changed).
    function reloadSelectedInfo() {
        const t = procs.tab;
        const currentSession = t.selectedIndex >= 0 && t.selectedIndex < t.filteredSessions.length ? t.filteredSessions[t.selectedIndex] : null;
        if (currentSession && !TmuxModel.isCreateRow(currentSession))
            t.loadSessionInfo(currentSession.name);
    }

    Process {
        id: tmuxProcess
        command: TmuxModel.LIST_SESSIONS
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                procs.tab.tmuxSessions = TmuxModel.parseSessions(text);
                procs.tab.updateFilteredSessions();
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                procs.tab.tmuxSessions = [];
                procs.tab.updateFilteredSessions();
            }
        }
    }

    Process {
        id: killProcess
        running: false

        onExited: function (code) {
            if (code === 0)
                procs.tab.refreshTmuxSessions();
        }
    }

    Process {
        id: renameProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                // Select the renamed session once the list is refreshed.
                procs.tab.pendingRenamedSession = procs.tab.newSessionName;
                procs.tab.refreshTmuxSessions();
            }
            procs.tab.cancelRenameMode();
        }
    }

    Process {
        id: windowsProcess
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: procs.tab.sessionWindows = TmuxModel.parseWindows(text)
        }
    }

    Process {
        id: panesProcess
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                procs.tab.sessionPanes = TmuxModel.parsePanes(text);
                procs.tab.loadingSessionInfo = false;
            }
        }

        onExited: function (code) {
            if (code !== 0) {
                procs.tab.sessionPanes = [];
                procs.tab.loadingSessionInfo = false;
            }
        }
    }

    Process {
        id: switchWindowProcess
        running: false

        onExited: function (code) {
            if (code === 0)
                procs.reloadSelectedInfo();
        }
    }

    Process {
        id: focusPaneProcess
        running: false

        onExited: function (code) {
            if (code === 0)
                procs.reloadSelectedInfo();
        }
    }
}
