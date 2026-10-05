pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services
import qs.config

// First-run setup wizard state (modules/onboarding). shell.qml loads the
// window while `visible`; `<app> run onboarding`, the launcher command and
// Settings > About reopen it. It opens by itself once, a few seconds after
// startup, only while `general.onboardingDone` is false (fresh installs:
// Config.qml marks general.json files from before the wizard as done).
Singleton {
    id: root

    property bool visible: false
    // Screen the wizard opened on (the focused one at that moment).
    property string screenName: ""
    // A keybind-tour task opened a panel: the wizard steps aside until the
    // panel closes (OnboardingWindow hides while this is true).
    property bool suspended: false

    readonly property bool done: Config.general ? Config.general.onboardingDone === true : true

    function open() {
        const mon = YozdService.focusedMonitor;
        screenName = mon && mon.name ? mon.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        suspended = false;
        if (Visibilities.currentActiveModule !== "")
            Visibilities.setActiveModule("");
        visible = true;
    }

    function close() {
        visible = false;
        suspended = false;
    }

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    // Finished or skipped: never auto-show again.
    function complete() {
        if (Config.general && Config.general.onboardingDone !== true) {
            Config.general.onboardingDone = true;
            Config.saveGeneral();
        }
        close();
    }

    property Timer autoShow: Timer {
        interval: 3500
        running: Config.initialLoadComplete && !root.done && !root.visible
        onTriggered: {
            if (!root.done)
                root.open();
        }
    }
}
