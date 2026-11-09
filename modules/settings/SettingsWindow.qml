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
    visible: GlobalStates.settingsWindowVisible

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
        if (!settingsWindow.homed)
            return;
        const target = SettingsScreen.rehomeTarget(outputs.output, settingsWindow.targetScreen);
        if (!target)
            return;
        settingsWindow.rehoming = true;
        settingsWindow.targetScreen = target;
        Qt.callLater(() => settingsWindow.rehoming = false);
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
    }

    // Unsaved staged changes are never dropped silently: a close request
    // (close button, keybind, window manager) keeps the window and asks.
    Connections {
        target: GlobalStates
        function onSettingsWindowVisibleChanged() {
            if (!GlobalStates.settingsWindowVisible && SettingsStore.hasChanges) {
                GlobalStates.settingsCloseConfirm = true;
                GlobalStates.settingsWindowVisible = true;
            }
        }
    }

    // Close on visibility change from outside
    onVisibleChanged: {
        if (visible) {
            preparePlacement();
        } else if (GlobalStates.settingsWindowVisible && !rehoming) {
            GlobalStates.settingsWindowVisible = false;
        }
    }
}
