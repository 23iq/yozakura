pragma Singleton
import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config

// Main shell side of performance.separateWindows: Settings and the setup
// wizard run as their own Quickshell processes (settings-window.qml,
// onboarding-window.qml) that the daemon starts on demand
// (backend/pkg/svc/windows). Every way to open them stays the same: they
// set GlobalStates.settingsWindowVisible / OnboardingService.visible as
// before; this service turns that into windows.open / windows.close and
// keeps the flags mirroring the process (true while it runs), so toggles,
// the dashboard button and the keybind tour see the real state.
// shell.qml loads the in-process windows only while `*Separate` is false.
// A window open in-process stays in-process until it closes (the setting
// can change while it is open); a window process that could not start
// falls back to the in-process window. It also relays staged previews into
// Config (PreviewSink) and runs what a window asks of the main shell
// (windows.relay to "shell": wallpaper changes, opening the other window).
Singleton {
    id: root

    readonly property bool wanted: ProcessRole.primary && Config.performance.separateWindows === true

    // Per kind, from the daemon: "closed" | "starting" | "open" | "hiding"
    // (closed by the user, the process quits in a moment; an open raises it)
    property string settingsState: "closed"
    property string wizardState: "closed"
    readonly property bool settingsRunning: root.settingsState !== "closed"
    readonly property bool wizardRunning: root.wizardState !== "closed"
    // Asked to open and not shown yet (the "Opening..." pill).
    readonly property bool settingsOpening: root._settingsAsked && root.settingsState !== "open"
    readonly property bool wizardOpening: root._wizardAsked && root.wizardState !== "open"
    property bool _settingsAsked: false
    property bool _wizardAsked: false

    property bool _settingsInProcess: false
    property bool _wizardInProcess: false
    readonly property bool settingsSeparate: ProcessRole.primary && !root._settingsInProcess && (root.wanted || root.settingsRunning)
    readonly property bool wizardSeparate: ProcessRole.primary && !root._wizardInProcess && (root.wanted || root.wizardRunning)

    // Methods of the wallpaper manager a window may ask for (RemoteWallpapers).
    readonly property var wallpaperMethods: ["setWallpaper", "setWallpaperDir", "setMatugenScheme", "setColorPreset", "clearPerScreenWallpaper", "clearAllPerScreenWallpapers", "nextWallpaper", "previousWallpaper"]

    property PreviewSink sink: PreviewSink {}

    // A relay to the shell no case below handles, for the feature that owns
    // it (DesktopWidgets: desktop.editMode).
    signal relayed(string topic, var data)

    // ---- daemon streams (subscribed once the setting is first on) ----
    property bool _subscribed: false
    function _subscribe() {
        if (root._subscribed || !root.wanted)
            return;
        root._subscribed = true;
        BackendService.addSubscription(["windows"], (service, data) => root._onWindows(service, data));
        BackendService.addSubscription(["preview"], (service, data) => root.sink.handle(service, data));
    }
    onWantedChanged: root._subscribe()
    Component.onCompleted: root._subscribe()

    function _onWindows(service, data) {
        if (!data)
            return;
        if (service === "windows.state") {
            if (data.kind === "settings")
                root._settingsState(String(data.state || "closed"));
            else if (data.kind === "onboarding")
                root._wizardState(String(data.state || "closed"));
        } else if (service === "windows.relay" && data.to === "shell") {
            root.relay(String(data.topic || ""), data.data || {});
        }
    }

    // What a window asks of the main shell.
    function relay(topic, data) {
        if (topic === "wallpaper.call") {
            const m = GlobalStates.wallpaperManager;
            const method = String(data.method || "");
            if (m && root.wallpaperMethods.indexOf(method) !== -1 && typeof m[method] === "function")
                m[method].apply(m, Array.isArray(data.args) ? data.args : []);
        } else if (topic === "colors.regenerate") {
            Colors.regenerateApps();
        } else if (topic === "onboarding.open") {
            OnboardingService.open();
        } else if (topic === "settings.open") {
            if (data.page)
                GlobalStates.settingsCategory = String(data.page);
            if (!GlobalStates.settingsWindowVisible)
                GlobalShortcuts.toggleSettings();
        } else {
            root.relayed(topic, data);
        }
    }

    // ---- Settings ----
    property bool _syncing: false
    function _setSettingsVisible(v) {
        if (GlobalStates.settingsWindowVisible === v)
            return;
        root._syncing = true;
        GlobalStates.settingsWindowVisible = v;
        root._syncing = false;
    }

    function _settingsState(state) {
        const prev = root.settingsState;
        root.settingsState = state;
        if (state === "closed") {
            // Asked again while it was hiding, and it quit before the raise
            // reached it: a new process.
            const again = root._settingsAsked && prev === "hiding" && GlobalStates.settingsWindowVisible && !root._settingsInProcess;
            root._settingsAsked = false;
            if (again)
                root._openSettings();
            else if (!root._settingsInProcess)
                root._setSettingsVisible(false);
        } else if (!root._settingsInProcess) {
            root._setSettingsVisible(state !== "hiding");
        }
    }

    // windows.open: starts the process, or raises the running one. A start
    // the daemon cannot make (no daemon: `qs -p shell.qml` alone; no answer
    // within openTimeout; entry file missing, Quickshell failed) opens the
    // in-process window instead.
    readonly property int openTimeout: 3000
    property bool _settingsPending: false // a start asked, not answered yet
    function _openSettings() {
        root._settingsAsked = true;
        const start = !root.settingsRunning;
        if (start && !BackendService.socketAvailable) {
            root._settingsFallback("no daemon connection");
            return;
        }
        if (start) {
            root._settingsPending = true;
            settingsGuard.restart();
        }
        BackendService.call("windows.open", {
            "kind": "settings",
            "page": GlobalStates.settingsCategory || "",
            "screen": GlobalStates.settingsTargetScreenName || "",
            "workspace": GlobalStates.settingsTargetWorkspaceId || 0
        }, (result, error) => {
            if (!start)
                return;
            // answered after the guard fell back: that window is not wanted
            if (!root._settingsPending) {
                if (!error)
                    BackendService.call("windows.close", {
                        "kind": "settings"
                    });
                return;
            }
            root._settingsPending = false;
            settingsGuard.stop();
            if (error)
                root._settingsFallback(error);
        });
    }
    function _settingsFallback(why) {
        console.warn("SeparateWindows: settings window not started (" + why + "), opening it in-process");
        root._settingsPending = false;
        settingsGuard.stop();
        root._settingsAsked = false;
        if (!root.settingsRunning)
            root._settingsInProcess = GlobalStates.settingsWindowVisible;
    }
    property Timer settingsGuard: Timer {
        interval: root.openTimeout
        onTriggered: {
            if (root._settingsPending && !root.settingsRunning)
                root._settingsFallback("no answer from the daemon");
        }
    }

    Connections {
        target: GlobalStates
        function onSettingsWindowVisibleChanged() {
            if (root._syncing)
                return;
            if (GlobalStates.settingsWindowVisible) {
                if (!root.settingsSeparate)
                    root._settingsInProcess = true;
                else if (!root.settingsRunning || root.settingsState === "hiding")
                    root._openSettings();
                return;
            }
            if (root._settingsInProcess) {
                root._settingsInProcess = false;
            } else if (root.settingsRunning) {
                // The window decides (it asks about unsaved changes); the
                // flag stays up until its process is gone.
                BackendService.call("windows.close", {
                    "kind": "settings"
                });
                Qt.callLater(() => root._setSettingsVisible(root.settingsRunning));
            } else {
                root._settingsAsked = false;
            }
        }
        // Another part of the shell asks for a page while the window runs.
        function onSettingsCategoryChanged() {
            if (root.settingsRunning && !root._settingsInProcess && GlobalStates.settingsWindowVisible)
                root._openSettings();
        }
    }

    // ---- Setup wizard ----
    property bool _wizardSyncing: false
    function _setWizardVisible(v) {
        if (OnboardingService.visible === v)
            return;
        root._wizardSyncing = true;
        OnboardingService.visible = v;
        if (!v) {
            OnboardingService.peek = false;
            // closed, finished or crashed: never auto-shown again this session
            OnboardingService.dismissedThisSession = true;
        }
        root._wizardSyncing = false;
    }

    function _wizardState(state) {
        const prev = root.wizardState;
        root.wizardState = state;
        if (state === "closed") {
            const again = root._wizardAsked && prev === "hiding" && OnboardingService.visible && !root._wizardInProcess;
            root._wizardAsked = false;
            if (again)
                root._openWizard();
            else if (!root._wizardInProcess)
                root._setWizardVisible(false);
        } else if (!root._wizardInProcess) {
            root._setWizardVisible(state !== "hiding");
            if (state === "open")
                root._sendShellState();
        }
    }

    // What a separate wizard cannot see itself: whether one of this shell's
    // panels is open (the keybind tour waits for it to close) and the
    // bottom bar of its screen (the peek pill sits above it).
    readonly property var _shellState: root.wizardRunning && !root._wizardInProcess ? ({
            "panelOpen": Visibilities.currentActiveModule !== "" || GlobalStates.assistantVisible === true || GlobalStates.settingsWindowVisible === true,
            "bottomZone": (Visibilities.reservations[OnboardingService.screenName] || {}).bottomZone || 0
        }) : null
    on_ShellStateChanged: root._sendShellState()
    function _sendShellState() {
        if (root._shellState)
            BackendService.call("windows.relay", {
                "to": "onboarding",
                "topic": "shell.state",
                "data": root._shellState
            });
    }

    property bool _wizardPending: false
    function _openWizard() {
        root._wizardAsked = true;
        const start = !root.wizardRunning;
        if (start && !BackendService.socketAvailable) {
            root._wizardFallback("no daemon connection");
            return;
        }
        if (start) {
            root._wizardPending = true;
            wizardGuard.restart();
        }
        BackendService.call("windows.open", {
            "kind": "onboarding",
            "screen": OnboardingService.screenName || ""
        }, (result, error) => {
            if (!start)
                return;
            if (!root._wizardPending) {
                if (!error)
                    BackendService.call("windows.close", {
                        "kind": "onboarding"
                    });
                return;
            }
            root._wizardPending = false;
            wizardGuard.stop();
            if (error)
                root._wizardFallback(error);
        });
    }
    function _wizardFallback(why) {
        console.warn("SeparateWindows: setup wizard not started (" + why + "), opening it in-process");
        root._wizardPending = false;
        wizardGuard.stop();
        root._wizardAsked = false;
        if (!root.wizardRunning)
            root._wizardInProcess = OnboardingService.visible;
    }
    property Timer wizardGuard: Timer {
        interval: root.openTimeout
        onTriggered: {
            if (root._wizardPending && !root.wizardRunning)
                root._wizardFallback("no answer from the daemon");
        }
    }

    Connections {
        target: OnboardingService
        function onVisibleChanged() {
            if (root._wizardSyncing)
                return;
            if (OnboardingService.visible) {
                if (!root.wizardSeparate)
                    root._wizardInProcess = true;
                else if (!root.wizardRunning || root.wizardState === "hiding")
                    root._openWizard();
                return;
            }
            if (root._wizardInProcess) {
                root._wizardInProcess = false;
            } else if (root.wizardRunning) {
                BackendService.call("windows.close", {
                    "kind": "onboarding"
                });
                Qt.callLater(() => root._setWizardVisible(root.wizardRunning));
            } else {
                root._wizardAsked = false;
            }
        }
    }
}
