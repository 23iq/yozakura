import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        const fmt = (c) => c.toString()

        const color4 = fmt(Colors.primary)
        const color0 = fmt(Colors.background)
        const color7 = fmt(Colors.secondary)
        const color8 = fmt(Colors.outline)

        let css = `:root {
  --zen-primary-color: ${color4} !important;
  --zen-branding-dark: ${color0} !important;
  --zen-branding-paper: ${color7} !important;
  --zen-main-browser-background: ${color0} !important;
  --zen-main-browser-background-toolbar: ${color0} !important;
  --zen-navigator-toolbox-background: ${color0} !important;
  --toolbar-bgcolor: ${color0} !important;
  --zen-themed-toolbar-bg-transparent: ${color0} !important;
  --arrowpanel-background: ${color0} !important;
  --arrowpanel-color: ${color7} !important;
  --arrowpanel-border-color: ${color8} !important;
}

.zen-toolbar-background,
#zen-main-app-wrapper {
  background: ${color0} !important;
}

.zen-browser-generic-background::after,
.zen-browser-generic-background::before {
  background: ${color0} !important;
}
`

        const outputPath = Brand.cacheDir + "/pywalzen.css"
        // $1 output file, $2 css
        writerProcess.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf \'%s\\n\' "$2" > "$1"', Brand.appId + "-pywalzen", outputPath, css]
        writerProcess.running = true
    }

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("PywalZenGenerator: Theme generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) {
                    const text = err.toString().trim()
                    if (text) console.error("PywalZenGenerator Error:", text)
                }
            }
        }
    }
}
