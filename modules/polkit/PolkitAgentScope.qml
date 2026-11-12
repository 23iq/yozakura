pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.modules.globals
import qs.modules.services

// The registered polkit agent and the request in front of the user
// (loaded by PolkitHost only while system.polkitAgent is on). Rules:
// - Requests come one at a time: Quickshell queues the next and makes it
//   `agent.flow` when the current one ends; a new flow resets the dialog
//   (empty field, focus, its own message) and opens on the screen focused
//   at that moment.
// - The caller cancelling (polkitd CancelAuthentication) completes the flow:
//   the dialog closes, nothing else is needed.
// - Locked session: the request is cancelled, never held. Holding it would
//   show an action somebody (or a script) asked for while the user was
//   away, out of its context, the moment they unlock; a cancel ends the
//   caller at once with "not authorized" and the user starts it again. The
//   dialog is never drawn while the lock screen is up. Only the shell's own
//   lock screen is seen (GlobalStates.lockscreenVisible): under an external
//   locker (hyprlock, swaylock) the request stays pending behind the lock
//   and the dialog shows after unlocking; neither the daemon nor yozd
//   tracks logind's LockedHint today.
// - Screen hotplug: the dialog lives on its screen's delegate; when that
//   output goes, it opens again on the focused one (the typed text is
//   dropped with the window). With no output at all it waits, unplaced,
//   and opens on the first one that comes back (re-picked on every change
//   of the screen list); dialogOpen is true only while a window is placed.
// - Shell reload / quit: a pending request is cancelled before the agent
//   goes away, so the caller gets a cancellation instead of waiting.
// - Another agent already registered (the user's own, or hyprpolkitagent
//   from an older config): ours stays unregistered; one log line, and the
//   other agent is left alone.
Scope {
    id: root

    readonly property AuthFlow flow: agent.flow
    readonly property bool locked: GlobalStates.lockscreenVisible
    readonly property bool pending: root.waiting(root.flow)
    readonly property bool open: root.pending && !root.locked
    // Output the dialog is on (the focused one when the request came)
    property string screenName: ""
    readonly property bool screenPresent: Quickshell.screens.some(s => s && s.name === root.screenName)
    readonly property bool placed: root.open && root.screenName !== "" && root.screenPresent

    // Read from the flow itself: in a change handler the `pending` binding
    // may not have caught up yet.
    function waiting(f: AuthFlow): bool {
        return f !== null && !f.isCompleted && !f.isCancelled;
    }

    function cancel(reason: string) {
        const f = root.flow;
        if (!root.waiting(f))
            return;
        console.info("polkit:", reason, "- request for", f.actionId, "cancelled");
        f.cancelAuthenticationRequest();
    }

    // The focused output, or the first one while the compositor still
    // names one that is gone.
    function pickScreen(): string {
        const name = GlobalStates.focusedScreenName();
        if (Quickshell.screens.some(s => s && s.name === name))
            return name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function begin() {
        const f = root.flow;
        if (!root.waiting(f))
            return;
        console.info("polkit: authentication requested for", f.actionId);
        if (root.locked) {
            root.cancel("session locked");
            return;
        }
        root.screenName = root.pickScreen();
    }

    onFlowChanged: root.begin()
    onLockedChanged: {
        if (root.locked)
            root.cancel("session locked");
    }
    // Re-picked on the next tick, once the screen list has settled.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            Qt.callLater(root.repick);
        }
    }
    function repick() {
        if (root.waiting(root.flow) && !root.screenPresent)
            root.screenName = root.pickScreen();
    }
    Component.onDestruction: {
        root.cancel("agent unloaded");
        PolkitService.registered = false;
        PolkitService.dialogOpen = false;
    }

    PolkitAgent {
        id: agent
        objectName: "polkitAgent"
    }

    Binding {
        target: PolkitService
        property: "registered"
        value: agent.isRegistered
    }
    Binding {
        target: PolkitService
        property: "dialogOpen"
        value: root.placed
    }
    // Registration is asynchronous; polkitd refuses a second agent for the
    // session. Said once, then this instance stays out of the way.
    Timer {
        objectName: "registrationCheck"
        interval: 5000
        running: !agent.isRegistered
        onTriggered: console.info("polkit: the in-shell agent is not registered (another polkit agent holds this session, or polkit is unavailable); password prompts stay with it")
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: slot
            required property ShellScreen modelData
            active: root.open && slot.modelData !== null && slot.modelData.name === root.screenName
            sourceComponent: PolkitWindow {
                targetScreen: slot.modelData
                flow: root.flow
            }
        }
    }
}
