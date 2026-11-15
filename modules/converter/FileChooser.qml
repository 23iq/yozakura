import QtQuick
import Quickshell.Io
import qs.modules.services
import "ConverterModel.js" as Model

// The desktop's file dialog (zenity, else kdialog), as PathControl uses it,
// with several files at once: chosen(paths) when the user picks files,
// unavailable() when neither dialog is installed. Fixed script; the title
// is a positional argument.
Process {
    id: root

    signal chosen(var paths)
    signal unavailable

    function open() {
        if (!root.running)
            root.running = true;
    }

    command: ["sh", "-c", "title=\"$1\"; if command -v zenity >/dev/null; then exec zenity --file-selection --multiple --separator='\n' --title=\"$title\"; elif command -v kdialog >/dev/null; then exec kdialog --getopenfilename \"$HOME\" --multiple --separate-output --title \"$title\"; else exit 127; fi", "sh", I18n.t("converter.choose")]

    onExited: code => {
        if (code === 127)
            root.unavailable();
        else if (code === 0)
            root.chosen(Model.chooserPaths(out.text));
    }

    stdout: StdioCollector {
        id: out
    }
}
