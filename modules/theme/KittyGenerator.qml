import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.theme
import "ColorUtils.js" as ColorUtils
import qs.modules.globals

QtObject {
    id: root

    // theme.terminalOpacity when set (0..1), otherwise the srBg opacity so
    // presets without the key keep their previous terminal look; scaled by
    // the glass "terminal" surface (Glass.qml, legibility-clamped).
    function terminalOpacity() {
        return Glass.terminalOpacity;
    }

    // Settings > Terminal: padding and cursor (terminal domain, see
    // config/defaults/terminal.js). kitty blinks when the interval is not 0.
    // Nothing until the user turns the terminal look on (terminal.enabled):
    // kitty's own padding and cursor are never replaced by our defaults.
    function lookKeys() {
        const t = Config.terminal;
        if (!t || !t.enabled)
            return "";
        const shapes = ["block", "beam", "underline"];
        const shape = t && shapes.indexOf(t.cursorShape) >= 0 ? t.cursorShape : "beam";
        const padding = t ? Math.max(0, Math.min(64, Math.round(Number(t.padding)))) : 12;
        const blink = !t || t.cursorBlink;
        let out = `window_padding_width ${isNaN(padding) ? 12 : padding}\n`;
        out += `cursor_shape ${shape}\n`;
        out += `cursor_blink_interval ${blink ? "-1" : "0"}\n`;
        return out;
    }

    function generate(Colors) {
        if (!Colors)
            return;
        const fmt = c => c.toString();

        const cursor = fmt(Colors.overSurface);
        const cursorText = fmt(Colors.overSurfaceVariant);

        const foreground = fmt(Colors.overSurface);
        const background = fmt(Colors.background);
        const selectionForeground = fmt(Colors.overSecondary);
        const selectionBackground = fmt(Colors.secondaryFixedDim);
        const urlColor = fmt(Colors.primary);
        const backgroundOpacity = terminalOpacity();

        const dark = ColorUtils.isDark(ColorUtils.fromQml(fmt(Colors.background)));

        // black: color0 is a raised surface (pill/badge backgrounds), color8
        // ("bright black") is dim text such as comments and fish
        // autosuggestions, so it must stay readable on the background.
        const color0 = fmt(dark ? Colors.surfaceContainerHigh : Colors.overSurface);
        const color8 = fmt(Colors.outline);

        // red
        const color1 = fmt(Colors.red);
        const color9 = fmt(Colors.lightRed);

        // green
        const color2 = fmt(Colors.green);
        const color10 = fmt(Colors.lightGreen);

        // yellow
        const color3 = fmt(Colors.yellow);
        const color11 = fmt(Colors.lightYellow);

        // blue: hue-correct (harmonized) blue. The primary accent is exposed
        // as color16 below so prompts can still use it.
        const color4 = fmt(Colors.blue);
        const color12 = fmt(Colors.lightBlue);

        // magenta
        const color5 = fmt(Colors.magenta);
        const color13 = fmt(Colors.lightMagenta);

        // cyan
        const color6 = fmt(Colors.cyan);
        const color14 = fmt(Colors.lightCyan);

        // white
        const color7 = fmt(dark ? Colors.overSurfaceVariant : Colors.surfaceContainerHigh);
        const color15 = fmt(dark ? Colors.overSurface : Colors.surfaceContainerLowest);

        // Extended palette (256-color indexes 16-21, e.g. starship
        // "fg:16"): primary, onPrimary, primaryContainer,
        // onPrimaryContainer, secondary, tertiary.
        const extended = [Colors.primary, Colors.overPrimary, Colors.primaryContainer, Colors.overPrimaryContainer, Colors.secondary, Colors.tertiary];

        let conf = "";
        // Settings > Terminal & Apps: optional font (empty keeps kitty's own).
        const font = (Config.apps && Config.apps.kitty) ? String(Config.apps.kitty.font || "").replace(/[\r\n]+/g, " ").trim() : "";
        if (font !== "") {
            conf += `font_family ${font}\n`;
            conf += `font_size ${Math.max(4, Number(Config.apps.kitty.fontSize) || 11)}\n\n`;
        }
        conf += `cursor ${cursor}\n`;
        conf += `cursor_text_color ${cursorText}\n`;
        conf += lookKeys();
        conf += "\n";

        conf += `foreground ${foreground}\n`;
        conf += `background ${background}\n`;
        conf += `background_opacity ${backgroundOpacity}\n`;
        // Kitty only applies a reloaded background_opacity (SIGUSR1 below)
        // when this was enabled at startup; without it a preset switch would
        // need a terminal restart.
        conf += `dynamic_background_opacity yes\n`;
        conf += `selection_foreground ${selectionForeground}\n`;
        conf += `selection_background ${selectionBackground}\n`;
        conf += `url_color ${urlColor}\n\n`;

        conf += `# black\n`;
        conf += `color0 ${color0}\n`;
        conf += `color8 ${color8}\n\n`;

        conf += `# red\n`;
        conf += `color1 ${color1}\n`;
        conf += `color9 ${color9}\n\n`;

        conf += `# green\n`;
        conf += `color2 ${color2}\n`;
        conf += `color10 ${color10}\n\n`;

        conf += `# yellow\n`;
        conf += `color3 ${color3}\n`;
        conf += `color11 ${color11}\n\n`;

        conf += `# blue\n`;
        conf += `color4 ${color4}\n`;
        conf += `color12 ${color12}\n\n`;

        conf += `# magenta\n`;
        conf += `color5 ${color5}\n`;
        conf += `color13 ${color13}\n\n`;

        conf += `# cyan\n`;
        conf += `color6 ${color6}\n`;
        conf += `color14 ${color14}\n\n`;

        conf += `# white\n`;
        conf += `color7 ${color7}\n`;
        conf += `color15 ${color15}\n`;

        conf += `\n# ${Brand.appId} extended (primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, tertiary)\n`;
        for (let i = 0; i < extended.length; i++)
            conf += `color${16 + i} ${fmt(extended[i])}\n`;

        writer.text = conf;

        // QUICKSHELL-GIT: const kittyConfPath = Quickshell.cachePath("kitty.conf");
        const kittyConfPath = Brand.cacheDir + "/kitty.conf";

        // Ensure directory exists and write file; the contents travel as a
        // positional argument (the font name is user text).
        const cmd = 'mkdir -p "$(dirname "$1")" && printf \'%s\\n\' "$2" > "$1" && pkill -SIGUSR1 kitty';

        writerProcess.command = ["sh", "-c", cmd, Brand.appId + "-kitty", kittyConfPath, conf];
        writerProcess.running = true;
    }

    property QtObject writer: QtObject {
        id: writer
        property string text
    }

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("KittyGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                if (err)
                    console.error("KittyGenerator Error:", err);
            }
        }
    }
}
