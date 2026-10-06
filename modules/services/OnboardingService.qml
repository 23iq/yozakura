pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.onboarding
import qs.config

// First-run setup wizard state (modules/onboarding). shell.qml loads the
// window while `visible`; `<app> run onboarding`, the launcher command and
// Settings > About reopen it. The wizard state lives here (`wizard`) and is
// persisted by step id + choices (StateService "onboarding"), so a shell
// reload or crash resumes the wizard where it was; complete() clears it. It opens by itself once, a few seconds after
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
    // The wizard is minimised to a pill so the desktop can be used (the
    // window is unmapped, not destroyed).
    property bool peek: false

    // One instance, reset and restored by open(); the card binds to it.
    property OnboardingState wizard: OnboardingState {}

    readonly property bool done: Config.general ? Config.general.onboardingDone === true : true

    function open() {
        const saved = StateService.get("onboarding", null);
        wizard.reset();
        if (saved && typeof saved === "object")
            wizard.restore(saved.step, saved.choices);
        peek = false;
        _show();
    }

    // Open on a given step id (ignores any saved progress).
    function openAt(stepId) {
        wizard.reset();
        wizard.restore(stepId, ({}));
        peek = false;
        _show();
    }

    function _show() {
        const mon = YozdService.focusedMonitor;
        screenName = mon && mon.name ? mon.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        suspended = false;
        if (Visibilities.currentActiveModule !== "")
            Visibilities.setActiveModule("");
        visible = true;
    }

    function close() {
        visible = false;
        peek = false;
        suspended = false;
    }

    function toggle() {
        if (visible && peek)
            peek = false;
        else if (visible)
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
        if (StateService.initialized && StateService.get("onboarding", null) !== null)
            StateService.set("onboarding", null);
        close();
    }

    function persist() {
        if (!visible || !StateService.initialized)
            return;
        StateService.set("onboarding", {
            "step": wizard.stepId,
            "choices": wizard.choices
        });
    }

    Connections {
        target: root.wizard
        function onIndexChanged() {
            root.persist();
        }
        function onChoicesChanged() {
            root.persist();
        }
    }

    property Timer autoShow: Timer {
        interval: 3500
        running: Config.initialLoadComplete && StateService.initialized && !root.done && !root.visible
        onTriggered: {
            if (!root.done)
                root.open();
        }
    }
}
