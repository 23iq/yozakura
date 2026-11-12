//@ pragma UseQApplication
//@ pragma ShellId yozakura-onboarding
//@ pragma DataDir $BASE/yozakura
//@ pragma StateDir $BASE/yozakura

import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.dashboard.wallpapers
import qs.config

// The setup wizard as its own Quickshell process
// (performance.separateWindows), started by the daemon
// (backend/pkg/svc/windows) with <PREFIX>ROLE=onboarding when the main shell
// opens it (first-run auto-show, `<app> run onboarding`, Settings > About).
// Only the wizard and its peek pill run here, both loaded by URL; the
// display keep/revert prompt is the main shell's (it follows the daemon's
// session). Real changes, as in-process: settings through SettingsStore
// (staged ones preview on the desktop through the daemon's `preview` relay
// and are applied when the wizard finishes), installs and displays through
// the daemon, wallpapers through the main shell (RemoteWallpapers). The
// keybind tour hears the commands on the daemon's `ui` stream
// (GlobalShortcuts) and the main shell tells it whether one of its panels
// is open and where its bottom bar ends (windows.relay "shell.state").
// Quits when the wizard closes; the daemon reaps it.
ShellRoot {
    id: root

    readonly property int bundledFonts: FontRegistry.count
    property bool started: false
    property bool opened: false

    RemoteWallpapers {
        id: wallpapers
        Component.onCompleted: GlobalStates.wallpaperManager = wallpapers
    }

    Loader {
        active: root.started && OnboardingService.visible
        source: "modules/onboarding/OnboardingWindow.qml"
    }
    Loader {
        active: root.started && OnboardingService.visible && OnboardingService.peek
        source: "modules/onboarding/OnboardingPeekPill.qml"
    }

    // Config and the saved progress read: open (resumes where it was).
    Timer {
        interval: 50
        running: ProcessRole.wizard && !root.started && Config.initialLoadComplete && StateService.initialized
        onTriggered: {
            root.started = true;
            OnboardingService.open();
            if (ProcessRole.initialScreen !== "")
                OnboardingService.screenName = ProcessRole.initialScreen;
        }
    }

    Connections {
        target: root.started ? OnboardingService : null
        function onVisibleChanged() {
            if (OnboardingService.visible) {
                root.opened = true;
                BackendService.call("windows.ready", {
                    "kind": ProcessRole.role
                });
            } else if (root.opened) {
                quitTimer.restart();
            }
        }
    }
    // Closed: quit once the last config writes went out and a pending
    // exclusive-mode switch answered (its failure is notified from here,
    // through the daemon); at most a minute.
    Timer {
        id: quitTimer
        property int waited: 0
        interval: 1000
        onTriggered: {
            if (OnboardingService.visible)
                return;
            waited += interval;
            const pending = ExclusiveService.busy || OnboardingService.wizard._exclusivePending;
            if (pending && waited < 60000)
                restart();
            else
                Qt.quit();
        }
    }

    // From the daemon: a later open (come back from a peek), a close (the
    // main shell's toggle), the main shell's panel / bar state for the tour
    // and the peek pill.
    function event(service, data) {
        if (!data)
            return;
        if (service === "windows.command" && data.kind === ProcessRole.role) {
            if (data.action === "raise")
                OnboardingService.peek = false;
            else if (data.action === "close")
                OnboardingService.close();
        } else if (service === "windows.relay" && data.to === ProcessRole.role && data.topic === "shell.state") {
            const s = data.data || {};
            OnboardingService.shellPanelOpen = s.panelOpen === true;
            Visibilities.registerReservation(OnboardingService.screenName, {
                "bottomZone": Number(s.bottomZone) || 0
            });
        }
    }

    Component.onCompleted: {
        if (!ProcessRole.wizard) {
            console.error("onboarding-window.qml is started by the " + Brand.appId + " daemon (performance.separateWindows), not by hand");
            Qt.quit();
            return;
        }
        BackendService.addSubscription(["windows"], (service, data) => root.event(service, data));
    }
}
