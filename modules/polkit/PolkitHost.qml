import QtQuick
import Quickshell
import qs.config
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
}
