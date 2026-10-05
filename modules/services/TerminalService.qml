pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property string binary: Config.general?.terminal ?? "kitty"
    readonly property bool advanced: Config.general?.terminalAdvanced ?? false
    readonly property string commandTemplate: Config.general?.terminalCommand ?? "$TERMINAL -e $COMMAND"

    // A plain terminal window (the "terminal" keybind / `<app> run terminal`).
    function open() {
        if (!binary) {
            console.warn("TerminalService: no terminal configured. Set Config.general.terminal.");
            return;
        }
        Quickshell.execDetached([binary]);
    }

    function execDetached(shellCmd) {
        if (!binary) {
            console.warn("TerminalService: no terminal configured. Set Config.general.terminal.");
            return;
        }

        if (advanced) {
            const rendered = commandTemplate
                .replace(/\$TERMINAL/g, binary)
                .replace(/\$COMMAND/g, shellCmd);
            Quickshell.execDetached(rendered);
        } else {
            Quickshell.execDetached([binary, "-e", "bash", "-c", shellCmd]);
        }
    }
}