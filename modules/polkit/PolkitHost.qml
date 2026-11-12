import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services

// The shell's own polkit authentication agent, for the instance whose root
// holds a `PolkitHost {}` (shell.qml only). Only one agent can be
// registered per session: any other Quickshell instance (the dry-run
// wizard, a future Settings or wizard process) leaves it out, or sets
// `enabled: false`, and never registers one.
//
// The agent (PolkitAgentScope.qml) is loaded by URL once the config says
// system.polkitAgent is on, so a Quickshell built without
// Quickshell.Services.Polkit only logs a line here and the shell starts
// as usual (the external agent then keeps the prompts).
Scope {
    id: root

    property bool enabled: true
    readonly property bool wanted: root.enabled && Config.systemReady && Config.system.polkitAgent !== false
    readonly property bool loaded: agent.status === Loader.Ready
    // Our listener was registered: turned off at runtime, nothing else
    // would answer prompts until the next login.
    property bool _hadListener: false
    // What the daemon is told (compositor.setPolkitState): `<app>
    // polkit-fallback` starts the external agent unless this says
    // "registered". Empty until the config is read, and in an instance
    // that holds no agent.
    readonly property string agentState: {
        if (!root.enabled || !Config.systemReady)
            return "";
        if (!root.wanted)
            return "off";
        if (agent.status === Loader.Error)
            return "unavailable";
        return PolkitService.registered ? "registered" : "pending";
    }

    function report() {
        if (root.agentState !== "")
            BackendService.notify("compositor.setPolkitState", {
                state: root.agentState,
                pid: Quickshell.processId
            });
    }
    onAgentStateChanged: root.report()
    Component.onCompleted: root.report()

    Loader {
        id: agent
        active: root.wanted
        source: "PolkitAgentScope.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("polkit: this Quickshell has no Quickshell.Services.Polkit module; password prompts stay with an external agent");
        }
    }

    Binding {
        target: PolkitService
        property: "available"
        value: root.loaded
    }

    // A restarted daemon starts without a report.
    Connections {
        target: BackendService
        function onSocketAvailableChanged() {
            if (BackendService.socketAvailable)
                root.report();
        }
    }

    Connections {
        target: PolkitService
        function onRegisteredChanged() {
            if (PolkitService.registered)
                root._hadListener = true;
        }
    }

    // system.polkitAgent turned off while our listener held the session:
    // start the external agent now (`<app> polkit-fallback`, which checks
    // the setting itself) once ours has unregistered.
    onWantedChanged: {
        if (!root.wanted && root._hadListener && Config.systemReady) {
            root._hadListener = false;
            fallbackDelay.restart();
        }
    }
    Timer {
        id: fallbackDelay
        interval: 1000
        onTriggered: Quickshell.execDetached([Brand.appBin, "polkit-fallback"])
    }
}
