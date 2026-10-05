import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "ColorUtils.js" as ColorUtils
import "TelegramTheme.js" as TelegramTheme

// Writes <cache dir>/<app id>.tdesktop-theme (Telegram Desktop / AyuGram /
// 64Gram...). Telegram cannot hot-reload themes: open the file once from the
// client ("Keep changes") and re-open it to pick up a new palette.
QtObject {
    id: root

    // Generation spawns ffmpeg/magick; skip when neither palette nor
    // wallpaper changed (the timer also fires on unrelated config edits).
    property string lastKey: ""
    property var pendingCommand: null

    function generate(Colors) {
        if (!Colors)
            return;
        try {
            const p = ColorUtils.palette(Colors);
            const text = TelegramTheme.build(p);

            let wallpaper = "";
            if (typeof GlobalStates !== "undefined" && GlobalStates.wallpaperManager)
                wallpaper = GlobalStates.wallpaperManager.currentWallpaper || "";

            const key = wallpaper + "\n" + text;
            if (key === root.lastKey)
                return;
            root.lastKey = key;

            const home = Quickshell.env("HOME");
            const out = Brand.cacheDir + "/" + Brand.appId + ".tdesktop-theme";

            const command = ["sh", "-c", root.script, Brand.appId + "-telegram", out, text, wallpaper, p.background];
            if (writerProcess.running) {
                root.pendingCommand = command;
                return;
            }
            writerProcess.command = command;
            writerProcess.running = true;
        } catch (e) {
            console.error("TelegramGenerator: generate failed:", e);
        }
    }

    // $1 output zip, $2 colors.tdesktop-theme contents, $3 wallpaper, $4 background color
    readonly property string script: `
        out="$1"; colors="$2"; wall="$3"; bg="$4"
        data="\${XDG_DATA_HOME:-$HOME/.local/share}"
        found=""
        for b in telegram-desktop ayugram-desktop AyuGram 64gram-desktop kotatogram-desktop materialgram Telegram; do
            command -v "$b" >/dev/null 2>&1 && found=1 && break
        done
        for d in TelegramDesktop AyuGramDesktop 64Gram KotatogramDesktop materialgram; do
            [ -d "$data/$d" ] && found=1 && break
        done
        [ -d "$HOME/.var/app/org.telegram.desktop" ] && found=1
        [ -z "$found" ] && exit 0

        tmp="$(mktemp -d)" || exit 1
        trap 'rm -rf "$tmp"' EXIT
        printf '%s' "$colors" > "$tmp/colors.tdesktop-theme"

        if command -v magick >/dev/null 2>&1; then
            src=""
            case "$wall" in
                *.mp4|*.MP4|*.webm|*.mkv|*.mov|*.avi|*.gif)
                    if command -v ffmpeg >/dev/null 2>&1 && [ -f "$wall" ]; then
                        ffmpeg -v error -y -ss 1 -i "$wall" -frames:v 1 -vf scale=1280:-2 "$tmp/frame.png" </dev/null && src="$tmp/frame.png"
                    fi ;;
                *) [ -f "$wall" ] && src="$wall" ;;
            esac
            if [ -n "$src" ]; then
                magick "$src[0]" -resize '1280x720^' -gravity center -extent 1280x720 \\
                    -blur 0x14 -fill "$bg" -colorize 80% -quality 88 "$tmp/background.jpg" 2>/dev/null
            fi
            [ -f "$tmp/background.jpg" ] || magick -size 1x1 "xc:$bg" "$tmp/background.png" 2>/dev/null
        fi

        mkdir -p "$(dirname "$out")"
        rm -f "$tmp/theme.zip"
        if command -v zip >/dev/null 2>&1; then
            (cd "$tmp" && zip -qX theme.zip colors.tdesktop-theme background.* 2>/dev/null || zip -qX theme.zip colors.tdesktop-theme)
        elif command -v bsdtar >/dev/null 2>&1; then
            (cd "$tmp" && bsdtar --format zip -cf theme.zip colors.tdesktop-theme $(ls background.* 2>/dev/null))
        else
            cp "$tmp/colors.tdesktop-theme" "$tmp/theme.zip"
        fi
        mv -f "$tmp/theme.zip" "$out"
    `

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        onExited: {
            if (!root.pendingCommand)
                return;
            const next = root.pendingCommand;
            root.pendingCommand = null;
            Qt.callLater(() => {
                writerProcess.command = next;
                writerProcess.running = true;
            });
        }
        stdout: StdioCollector {
            onStreamFinished: console.log("TelegramGenerator: Theme generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                const text = err ? err.toString().trim() : "";
                if (text)
                    console.error("TelegramGenerator Error:", text);
            }
        }
    }
}
