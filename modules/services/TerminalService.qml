pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services

Singleton {
    id: root

    readonly property string binary: Config.general?.terminal ?? "kitty"
    readonly property bool advanced: Config.general?.terminalAdvanced ?? false
    readonly property string commandTemplate: Config.general?.terminalCommand ?? "$TERMINAL -e $COMMAND"
    // The login shell of a chsh made during this session ("" when there was
    // none, or until the terminal look read the status). Every supported
    // terminal starts $SHELL, and this session's $SHELL is the one from
    // login: after "make fish my default shell" new terminals would still
    // open the old shell until the next login. The backend decides it
    // (term.status terminalShell, termrun.ChangedShell): a $SHELL that
    // differed from passwd from the start is the user's choice and stays.
    readonly property string terminalShell: TerminalLookService.status?.terminalShell ?? ""

    // A plain terminal window (the "terminal" keybind / `<app> run terminal`).
    function open() {
        if (!binary) {
            console.warn("TerminalService: no terminal configured. Set Config.general.terminal.");
            return;
        }
        Quickshell.execDetached(ProcessRole.detached(root.withLoginShell([binary])));
    }

    // argv with $SHELL set to the shell of a chsh made this session (argv
    // as is without one); `env` takes the value as one argument, never as code.
    function withLoginShell(argv) {
        return root.terminalShell.startsWith("/") ? ["env", "SHELL=" + root.terminalShell].concat(argv) : argv;
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
            Quickshell.execDetached(ProcessRole.detached(rendered));
        } else {
            Quickshell.execDetached(ProcessRole.detached([binary, "-e", "bash", "-c", shellCmd]));
        }
    }
}
