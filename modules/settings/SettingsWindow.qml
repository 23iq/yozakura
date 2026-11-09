import QtQuick
import Quickshell
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.settings.store
import "SettingsScreen.js" as SettingsScreen

FloatingWindow {
    id: settingsWindow

    // Window properties
    implicitWidth: 1180
    implicitHeight: 780
    // Below this the page has no room for its cards and rows.
    minimumSize: Qt.size(640, 480)
    title: "Yozakura Settings"
    // Hidden for a moment while it moves to another output (moveTo()).
    visible: GlobalStates.settingsWindowVisible && !_parked
    property bool _parked: false

    color: "transparent"

    // The output, set once by the shell's Loader as an initial property
    // (before the backing window exists). Never bound: changing `screen`
    // while the window is visible forces quickshell to hide/show it, which
    // fires onVisibleChanged(false) (misread as an external close) and,
    // during output churn, crashes QtWayland. Refocusing another monitor
    // never remaps this window either.
    property ShellScreen targetScreen: null
    screen: targetScreen
    // Opened on a named output (else the compositor placed it: never moved).
    readonly property bool homed: _homed
    property bool _homed: false
    Component.onCompleted: _homed = targetScreen !== null
    // Moving to another output after ours went away (see rehome()).
    property bool rehoming: false
    // Our output is gone and the move has not happened yet: QtWayland may
    // hide the surface meanwhile, which is not the user closing it.
    readonly property bool outputGone: homed && SettingsScreen.indexIn(Quickshell.screens, targetScreen) < 0

    // Our output disappeared: once the outputs have settled, move to the
    // first one (one move, not one per hotplug event).
    SettleGate {
        id: outputs
        value: Quickshell.screens
        interval: 400
        onSettledChanged: {
            if (settled)
                settingsWindow.rehome();
        }
    }

    function rehome() {
        if (!settingsWindow.visible && settingsWindow.retarget())
            return;
        if (!settingsWindow.homed)
            return;
        const target = SettingsScreen.rehomeTarget(outputs.output, settingsWindow.targetScreen);
        if (!target)
            return;
        settingsWindow.moveTo(target);
    }

    // A hidden window moves at once. A mapped one is never moved while
    // mapped: hidden first, moved once the hide went through, then shown
    // again; `rehoming` covers the whole sequence, so the (asynchronous)
    // hide is not taken for the user closing it.
    function moveTo(target) {
        settingsWindow.rehoming = true;
        if (!settingsWindow.visible && !settingsWindow._parked) {
            settingsWindow.targetScreen = target;
            settingsWindow._homed = true;
            Qt.callLater(() => settingsWindow.rehoming = false);
            return;
        }
        rehomeSteps.target = target;
        settingsWindow._parked = true;
        rehomeSteps.step = 0;
        rehomeSteps.restart();
    }

    // hide -> (a few frames) move -> (a few frames) show -> clear the guard
    Timer {
        id: rehomeSteps
        property var target: null
        property int step: 0
        interval: 50
        onTriggered: {
            if (step === 0) {
                if (target) {
                    settingsWindow.targetScreen = target;
                    settingsWindow._homed = true;
                }
                target = null;
                step = 1;
                restart();
            } else if (step === 1) {
                settingsWindow._parked = false;
                step = 2;
                restart();
            } else {
                settingsWindow.rehoming = false;
            }
        }
    }

    // Kept alive hidden (KeepAliveLoader in shell.qml): the next open names
    // its output before it shows the window, so move only while hidden,
    // never a mapped window. True when it moved.
    function retarget() {
        if (settingsWindow.visible)
            return false;
        const target = SettingsScreen.byName(Quickshell.screens, GlobalStates.settingsTargetScreenName);
        if (!target || target === settingsWindow.targetScreen)
            return false;
        settingsWindow.moveTo(target);
        return true;
    }

    function preparePlacement() {
        placementTimer.attempts = 0;
        placementTimer.restart();
    }

    function placeOnTargetWorkspace() {
        const targetWorkspace = GlobalStates.settingsTargetWorkspaceId || YozdService.focusedMonitor?.activeWorkspace?.id || YozdService.focusedWorkspace?.id || 0;
        if (!targetWorkspace)
            return false;

        const clients = YozdService.clients.values || [];
        for (let i = 0; i < clients.length; i++) {
            const client = clients[i];
            if (client.title === settingsWindow.title) {
                if (client.workspace?.id !== targetWorkspace) {
                    YozdService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${client.address}`);
                }
                YozdService.dispatch(`focuswindow address:${client.address}`);
                return true;
            }
        }

        return false;
    }

    Timer {
        id: placementTimer
        interval: 100
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (!settingsWindow.visible || settingsWindow.placeOnTargetWorkspace() || attempts >= 20) {
                stop();
            }
        }
    }

    SettingsShell {
        anchors.fill: parent
        // While kept alive hidden (KeepAliveLoader), the pages see
        // visible=false: previews, polls and timers gated on it stop.
        visible: settingsWindow.visible
    }

    // Unsaved staged changes are never dropped silently: a close request
    // (close button, keybind, window manager) keeps the window and asks.
    Connections {
        target: GlobalStates
        function onSettingsTargetScreenNameChanged() {
            settingsWindow.retarget();
        }
        function onSettingsWindowVisibleChanged() {
            if (!GlobalStates.settingsWindowVisible && SettingsStore.hasChanges) {
                GlobalStates.settingsCloseConfirm = true;
                GlobalStates.settingsWindowVisible = true;
            }
        }
    }

    // Kept alive hidden between opens (KeepAliveLoader in shell.qml): a
    // preset trial or edit may have started meanwhile, bring back its pill.
    property bool shownBefore: false

    // Close on visibility change from outside
    onVisibleChanged: {
        if (visible) {
            // Back from a move to another output: stays where it went.
            if (!rehoming)
                preparePlacement();
            if (shownBefore)
                PresetStudio.refreshSessions();
            return;
        }
        shownBefore = true;
        if (GlobalStates.settingsWindowVisible && !rehoming && !outputGone) {
            GlobalStates.settingsWindowVisible = false;
        }
    }
}
