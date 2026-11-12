pragma Singleton
import QtQuick
import Quickshell

// State of the shell's own polkit authentication agent. The agent itself
// lives in modules/polkit (PolkitHost, placed in shell.qml only): an
// instance without a host (the dry-run wizard, a future Settings process)
// never registers one, and everything here stays false there. Only the
// host writes these.
Singleton {
    id: root

    // The host loaded the agent: system.polkitAgent is on and Quickshell
    // has Quickshell.Services.Polkit. The generated compositor config then
    // starts no external agent (CompositorTomlWriter, shellPolkit).
    property bool available: false
    // Our listener is registered with polkitd: password prompts come up in
    // the shell's dialog, above every shell surface (the setup wizard need
    // not step aside for them).
    property bool registered: false
    // The dialog is up: full-screen surfaces with exclusive keyboard focus
    // (the setup wizard) give the keyboard to it.
    property bool dialogOpen: false

    // The shell's own surfaces never hold or take the keyboard from the
    // dialog: while it is open Visibilities closes the open module and
    // refuses to open one, and GlobalShortcuts runs only the commands that
    // map no surface (allowsCommand). Locking stays possible (it cancels the
    // request).
    readonly property var _quietCommands: ["lockscreen"]
    readonly property var _quietPrefixes: ["media-", "brightness-", "dnd-", "wallpaper-"]
    function allowsCommand(command: string): bool {
        if (!root.dialogOpen)
            return true;
        const c = String(command);
        return root._quietCommands.indexOf(c) !== -1 || root._quietPrefixes.some(p => c.indexOf(p) === 0);
    }
}
