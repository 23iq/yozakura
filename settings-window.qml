//@ pragma UseQApplication
//@ pragma ShellId yozakura-settings
//@ pragma DataDir $BASE/yozakura
//@ pragma StateDir $BASE/yozakura

import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.dashboard.wallpapers
import "modules/settings/SettingsScreen.js" as SettingsScreen

// The Settings window as its own Quickshell process
// (performance.separateWindows). The daemon starts it on demand
// (backend/pkg/svc/windows) with <PREFIX>ROLE=settings, so ProcessRole keeps
// every session-wide service to the main shell, and the page / screen /
// workspace to open in <PREFIX>WINDOW_*. Only the window is named here (the
// content is loaded by URL, SettingsWindowSeparate.qml): the frame maps at
// once, then the pages compile and build. A later open asks this process
// to raise itself (windows.command); closing the window ends the process.
// Staged changes are one staging shared with the main shell and the wizard
// through the daemon's `preview` relay (SettingsStore, PreviewSink).
ShellRoot {
    id: root

    readonly property int bundledFonts: FontRegistry.count
    property bool shown: false
    // SettingsWindowSeparate, once loaded
    readonly property var win: windowLoader.item

    // The main shell's wallpaper manager, read from wallpapers.json; changes
    // are asked of the main shell.
    RemoteWallpapers {
        id: wallpapers
        Component.onCompleted: GlobalStates.wallpaperManager = wallpapers
    }

    function target(page, screen, workspace) {
        if (page)
            GlobalStates.settingsCategory = page;
        if (screen)
            GlobalStates.settingsTargetScreenName = screen;
        if (workspace > 0)
            GlobalStates.settingsTargetWorkspaceId = workspace;
    }

    Loader {
        id: windowLoader
        function load() {
            setSource("modules/settings/SettingsWindowSeparate.qml", {
                "targetScreen": SettingsScreen.byName(Quickshell.screens, GlobalStates.settingsTargetScreenName)
            });
        }
    }

    // The window is shown: tell the daemon (the main shell drops its
    // "Opening..." pill) and run what was asked while it started (a close
    // from the main shell's toggle, another page); closed (after the
    // unsaved-changes question): report hiding and quit, the daemon reaps
    // us. An open meanwhile raises it again (command).
    Connections {
        target: root.win
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (root.win.visible && !root.shown) {
                root.shown = true;
                BackendService.call("windows.ready", {
                    "kind": ProcessRole.role
                }, (result, error) => {
                    if (!error && result && result.command)
                        root.command(result.command);
                });
            }
        }
    }
    Connections {
        target: GlobalStates
        function onSettingsWindowVisibleChanged() {
            if (GlobalStates.settingsWindowVisible) {
                quitTimer.stop();
            } else {
                quitTimer.restart();
                // a close with unsaved changes reopens at once to ask
                Qt.callLater(root.reportHiding);
            }
        }
    }
    function reportHiding() {
        if (GlobalStates.settingsWindowVisible || !root.shown)
            return;
        root.shown = false;
        BackendService.call("windows.hiding", {
            "kind": ProcessRole.role
        });
    }
    // A moment after closing (it may reopen to ask about unsaved changes),
    // so the last config writes (Apply, an unstaged setting) reach the disk.
    Timer {
        id: quitTimer
        interval: 1000
        onTriggered: {
            if (GlobalStates.settingsWindowVisible)
                return;
            // an Apply waiting for the main shell (bounded): it may have
            // to write itself
            if (PreviewSink.applying)
                restart();
            else
                Qt.quit();
        }
    }

    // A later open (raise, maybe another page / screen) or a close asked by
    // the main shell (its toggle).
    function command(data) {
        if (!data || data.kind !== ProcessRole.role)
            return;
        if (data.action === "raise") {
            root.target(String(data.page || ""), String(data.screen || ""), Number(data.workspace) || 0);
            // closed and about to quit: shown again (cancels the quit)
            GlobalStates.settingsWindowVisible = true;
            if (root.win)
                root.win.preparePlacement();
        } else if (data.action === "close") {
            GlobalStates.settingsWindowVisible = false;
        }
    }

    Component.onCompleted: {
        if (!ProcessRole.settings) {
            console.error("settings-window.qml is started by the " + Brand.appId + " daemon (performance.separateWindows), not by hand");
            Qt.quit();
            return;
        }
        // the staging shared with the main shell and the other window
        PreviewSink.link();
        root.target(ProcessRole.initialPage, ProcessRole.initialScreen, ProcessRole.initialWorkspace);
        GlobalStates.settingsWindowVisible = true;
        BackendService.addSubscription(["windows"], (service, data) => {
            if (service === "windows.command")
                root.command(data);
        });
        windowLoader.load();
    }
}
