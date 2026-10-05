import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        // Helper to format color
        const fmt = (c) => c.toString()

        // Core colors
        const bg = Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, Config.theme.srBg.opacity).toString()
        const fg = fmt(Colors.overBackground)
        const surface = fmt(Colors.surface)
        const primary = fmt(Colors.primary)
        const secondary = fmt(Colors.secondary)
        const error = fmt(Colors.error)
        const inactive = fmt(Colors.outline)
        const link = fmt(Colors.tertiary)
        const selection = fmt(Colors.primary)
        const selectionFg = fmt(Colors.overPrimary)

        // Construct INI content
        let ini = ""

        ini += "[ColorEffects:Disabled]\n"
        ini += `Color=${bg}\n`
        ini += "ColorAmount=0.5\n"
        ini += "ColorEffect=3\n"
        ini += "ContrastAmount=0\n"
        ini += "ContrastEffect=0\n"
        ini += "IntensityAmount=0\n"
        ini += "IntensityEffect=0\n\n"

        ini += "[ColorEffects:Inactive]\n"
        ini += "ChangeSelectionColor=true\n"
        ini += `Color=${bg}\n`
        ini += "ColorAmount=0.025\n"
        ini += "ColorEffect=0\n"
        ini += "ContrastAmount=0.1\n"
        ini += "ContrastEffect=0\n"
        ini += "Enable=true\n"
        ini += "IntensityAmount=0\n"
        ini += "IntensityEffect=0\n\n"

        ini += "[Colors:Button]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${surface}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Complementary]\n"
        ini += `BackgroundAlternate=${bg}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Header]\n"
        ini += `BackgroundAlternate=${bg}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Header][Inactive]\n"
        ini += `BackgroundAlternate=${bg}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Selection]\n"
        ini += `BackgroundAlternate=${selection}\n`
        ini += `BackgroundNormal=${selection}\n`
        ini += `DecorationFocus=${selection}\n`
        ini += `DecorationHover=${selection}\n`
        ini += `ForegroundActive=${selectionFg}\n`
        ini += `ForegroundInactive=${selectionFg}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${selectionFg}\n`
        ini += `ForegroundNormal=${selectionFg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Tooltip]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:View]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Window]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[General]\n"
        ini += "ColorScheme=" + Brand.displayName + "\n"
        ini += "Name=" + Brand.displayName + "\n"
        ini += "shadeSortColumn=true\n"
        ini += "\n"
        
        ini += "[KDE]\n"
        ini += "contrast=4\n"
        ini += "\n"
        
        ini += "[WM]\n"
        ini += `activeBackground=${bg}\n`
        ini += "activeBlend=252,252,252\n" 
        ini += `activeForeground=${fg}\n`
        ini += `inactiveBackground=${fmt(Colors.surfaceDim)}\n`
        ini += "inactiveBlend=161,169,177\n"
        ini += `inactiveForeground=${inactive}\n`

        const home = Quickshell.env("HOME")
        const qt5Dir = home + "/.config/qt5ct/colors"
        const qt6Dir = home + "/.config/qt6ct/colors"

        writer.text = ini
        
        // Ensure dirs, write both files and point a qt5ct/qt6ct config that
        // still uses the legacy app's scheme file at the new one.
        const cmd = `
            ini="$1"; app="$2"; legacy="$3"
            for d in "$4" "$5"; do
                mkdir -p "$d" && printf '%s\\n' "$ini" > "$d/$app.colors" || exit 1
                conf="$(dirname "$d")/$(basename "$(dirname "$d")").conf"
                if [ "$legacy" != "$app" ] && [ -f "$conf" ] && grep -q "colors/$legacy\\.colors" "$conf"; then
                    sed "s#colors/$legacy\\.colors#colors/$app.colors#" "$conf" > "$conf.tmp" && mv -f "$conf.tmp" "$conf"
                fi
            done
        `
        
        writerProcess.command = ["sh", "-c", cmd, Brand.appId + "-qtct", ini, Brand.appId, Brand.legacyAppId, qt5Dir, qt6Dir]
        writerProcess.running = true
    }
    
    property QtObject writer: QtObject {
        id: writer
        property string text
    }

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("QtCtGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) console.error("QtCtGenerator Error:", err)
            }
        }
    }
}
