import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.theme
import qs.modules.globals
import "TerminalThemes.js" as TerminalThemes

// Writes <cache>/ghostty.conf from the shell palette; the apphooks backend hook
// connects ghostty to it. The font is the shared terminal font (Config.apps.kitty),
// the opacity the glass "terminal" surface, as for kitty.
QtObject {
    id: root

    function generate(Colors) {
        if (!Colors)
            return;
        const kitty = Config.apps ? Config.apps.kitty : null;
        const conf = TerminalThemes.ghostty(TerminalThemes.palette(Colors), {
            "font": kitty ? kitty.font : "",
            "fontSize": kitty ? kitty.fontSize : 11,
            "opacity": Glass.terminalOpacity
        });

        // The contents travel as a positional argument (the font name is user text).
        const cmd = 'mkdir -p "$(dirname "$1")" && printf \'%s\\n\' "$2" > "$1"';
        writerProcess.command = ["sh", "-c", cmd, Brand.appId + "-ghostty", Brand.cacheDir + "/ghostty.conf", conf];
        writerProcess.running = true;
    }

    property Process writerProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("GhosttyGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text)
                    console.error("GhosttyGenerator Error:", text);
            }
        }
    }
}
