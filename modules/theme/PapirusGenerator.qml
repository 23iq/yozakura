import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "ColorUtils.js" as ColorUtils

// Papirus folder colors without root: papirus-folders needs sudo for the
// system theme, so instead we keep a per-user overlay directory
// ~/.local/share/icons/<Papirus theme>/<size>/places/ containing only symlinks
// (folder*.svg, user-*.svg) to the system icons of the matched color.
// GTK and Qt merge same-named theme dirs across all icon search paths and the
// user dir comes first, so the overlay wins. No index.theme is written, so
// papirus-folders itself keeps managing the system copy.
QtObject {
    id: root

    // Front-face colors of Papirus' folder-<color>.svg (48x48).
    readonly property var folderColors: ({
            "black": "#4f4f4f",
            "blue": "#5294e2",
            "bluegrey": "#607d8b",
            "brown": "#ae8e6c",
            "carmine": "#a30002",
            "cyan": "#00bcd4",
            "darkcyan": "#45abb7",
            "deeporange": "#eb6637",
            "green": "#87b158",
            "grey": "#8e8e8e",
            "indigo": "#5c6bc0",
            "magenta": "#ca71df",
            "orange": "#ee923a",
            "palebrown": "#d1bfae",
            "paleorange": "#eeca8f",
            "pink": "#f06292",
            "red": "#e25252",
            "teal": "#16a085",
            "violet": "#7e57c2",
            "yellow": "#f9bd30"
        })

    function pickColor(primaryHex) {
        return ColorUtils.nearestByHue(primaryHex, folderColors, "grey");
    }

    function generate(Colors) {
        if (!Colors)
            return;
        try {
            const color = pickColor(ColorUtils.fromQml(Colors.primary.toString()));
            if (!color)
                return;
            writerProcess.command = ["sh", "-c", root.script, Brand.appId + "-papirus", color];
            writerProcess.running = true;
        } catch (e) {
            console.error("PapirusGenerator: generate failed:", e);
        }
    }

    // $1 papirus folder color name
    readonly property string script: `
        color="$1"
        theme="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
        case "$theme" in Papirus|Papirus-Dark|Papirus-Light|ePapirus|ePapirus-Dark) ;; *) exit 0 ;; esac
        sys=""
        for d in /usr/share/icons /usr/local/share/icons /run/current-system/sw/share/icons; do
            [ -f "$d/$theme/index.theme" ] && sys="$d/$theme" && break
        done
        [ -n "$sys" ] || exit 0
        user="\${XDG_DATA_HOME:-$HOME/.local/share}/icons/$theme"
        stamp="$user/.$0-folder-color"
        [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$color" ] && exit 0
        # Never clobber a real (non-overlay) user copy of the theme.
        [ -f "$user/index.theme" ] && exit 0

        for size in 22x22 24x24 32x32 48x48 64x64; do
            src="$sys/$size/places"
            [ -d "$src" ] || continue
            dst="$user/$size/places"
            mkdir -p "$dst" || exit 1
            find "$dst" -maxdepth 1 -type l -delete 2>/dev/null
            for f in "$src/folder-$color"*.svg "$src/user-$color"*.svg; do
                [ -f "$f" ] || continue
                name="\${f##*/}"
                case "$name" in folder-$color.svg|folder-$color-*.svg|user-$color.svg|user-$color-*.svg) ;; *) continue ;; esac
                ln -sf "$(readlink -f "$f")" "$dst/$(printf '%s' "$name" | sed "s/-$color//")"
            done
        done
        printf '%s' "$color" > "$stamp"
        exit 0
    `

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("PapirusGenerator: Folder color applied.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                const text = err ? err.toString().trim() : "";
                if (text)
                    console.error("PapirusGenerator Error:", text);
            }
        }
    }
}
