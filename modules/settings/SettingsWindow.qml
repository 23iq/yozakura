import QtQuick
import Quickshell
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config

FloatingWindow {
    id: settingsWindow

    // Window properties
    implicitWidth: 1180
    implicitHeight: 780
    title: "Yozakura Settings"
    visible: GlobalStates.settingsWindowVisible

    color: "transparent"

    // Resolve the target screen before the backing window is created.
    // Changing `screen` while the window is visible forces quickshell to
    // hide/show the window, which fires onVisibleChanged(false) and would
    // be misread as an external close.
    // Deliberately not bound to focusedMonitor so refocusing another
    // monitor while open never remaps this window.
    screen: screenByName(GlobalStates.settingsTargetScreenName)

    function screenByName(name) {
        if (!name)
            return null;

        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i];
            }
        }

        return null;
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

    // Close on visibility change from outside
    onVisibleChanged: {
        if (visible) {
            preparePlacement();
        } else if (GlobalStates.settingsWindowVisible) {
            GlobalStates.settingsWindowVisible = false;
        }
    }
}
