import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.theme
import qs.modules.globals
import "TerminalThemes.js" as TerminalThemes

// Writes <cache>/alacritty.toml from the shell palette; the apphooks backend hook
// connects alacritty to it. The font is the shared terminal font (Config.apps.kitty),
// the opacity the glass "terminal" surface, as for kitty.
QtObject {
    id: root

    function generate(Colors) {
        if (!Colors)
            return;
        const kitty = Config.apps ? Config.apps.kitty : null;
        const conf = TerminalThemes.alacritty(TerminalThemes.palette(Colors), {
            "font": kitty ? kitty.font : "",
            "fontSize": kitty ? kitty.fontSize : 11,
            "opacity": Glass.terminalOpacity
        });

        // The contents travel as a positional argument (the font name is user text).
        const cmd = 'mkdir -p "$(dirname "$1")" && printf \'%s\\n\' "$2" > "$1"';
        writerProcess.command = ["sh", "-c", cmd, Brand.appId + "-alacritty", Brand.cacheDir + "/alacritty.toml", conf];
        writerProcess.running = true;
    }

    property Process writerProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("AlacrittyGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text)
                    console.error("AlacrittyGenerator Error:", text);
            }
        }
    }
}
