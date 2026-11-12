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
    // The login shell as /etc/passwd has it now ("" until the terminal look
    // read it). Every supported terminal starts $SHELL, and this session's
    // $SHELL is the one from login: after "make fish my default shell" new
    // terminals would still open the old shell until the next login.
    readonly property string loginShell: TerminalLookService.status?.loginShell ?? ""

    // A plain terminal window (the "terminal" keybind / `<app> run terminal`).
    function open() {
        if (!binary) {
            console.warn("TerminalService: no terminal configured. Set Config.general.terminal.");
            return;
        }
        Quickshell.execDetached(root.withLoginShell([binary]));
    }

    // argv with $SHELL set to the current login shell (argv as is when it
    // is unknown); `env` takes the value as one argument, never as code.
    function withLoginShell(argv) {
        return root.loginShell.startsWith("/") ? ["env", "SHELL=" + root.loginShell].concat(argv) : argv;
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
