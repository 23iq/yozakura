import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.modules.globals

// Collects context for prompts: primary selection, clipboard (text or image),
// a screen region or the whole screen, a file, the active window. Results are
// attachments: {type: "text", kind, name, text} | {type: "image", kind, name, mimeType, base64, path}
QtObject {
    id: root

    readonly property Component procFactory: Component {
        Process {
            property var done: null
            stdout: StdioCollector {
                id: so
            }
            stderr: StdioCollector {
                id: se
            }
            onExited: code => {
                if (done)
                    done(code === 0, so.text, se.text);
                destroy();
            }
        }
    }

    function run(command, cb) {
        const p = procFactory.createObject(root, {
            command: command,
            done: cb
        });
        p.running = true;
    }

    // Raw text helpers (used by templates and automations).
    function selectionText(cb) {
        run(["wl-paste", "-p", "-n"], (ok, out) => cb(ok ? out : ""));
    }

    function clipboardText(cb) {
        run(["wl-paste", "-n", "-t", "text"], (ok, out) => cb(ok ? out : ""));
    }

    function selection(cb) {
        selectionText(text => cb(text.trim() ? {
                type: "text",
                kind: "selection",
                name: "selection",
                text: text
            } : null));
    }

    function clipboard(cb) {
        run(["wl-paste", "--list-types"], (ok, out) => {
            const types = ok ? out.split("\n").map(t => t.trim()) : [];
            const image = types.find(t => t.startsWith("image/"));
            if (image) {
                run(["sh", "-c", "wl-paste -t \"$1\" | base64 -w0", "sh", image], (ok2, b64) => cb(ok2 && b64 ? {
                        type: "image",
                        kind: "clipboard",
                        name: "clipboard." + image.split("/")[1],
                        mimeType: image,
                        base64: b64.trim()
                    } : null));
                return;
            }
            clipboardText(text => cb(text.trim() ? {
                    type: "text",
                    kind: "clipboard",
                    name: "clipboard",
                    text: text
                } : null));
        });
    }

    // region: true = slurp a region, false = focused output. The PNG is kept
    // in $XDG_RUNTIME_DIR/yozakura-ai so CLI agents can receive it as a file.
    function screenshot(region, cb) {
        const out = YozdService.focusedMonitor ? YozdService.focusedMonitor.name : "";
        const dir = Brand.runtimeFile("-ai");
        const file = dir + "/shot-" + Date.now() + ".png";
        // $1 dir, $2 output name, $3 file
        const script = region ? 'umask 077; mkdir -p "$1" && g=$(slurp) || exit 1; grim -g "$g" -t png "$3" && base64 -w0 "$3"' : 'umask 077; mkdir -p "$1" && grim ${2:+-o "$2"} -t png "$3" && base64 -w0 "$3"';
        run(["sh", "-c", script, "sh", dir, out, file], (ok, b64) => cb(ok && b64.trim() ? {
                type: "image",
                kind: "screenshot",
                name: region ? "region.png" : "screen.png",
                mimeType: "image/png",
                base64: b64.trim(),
                path: file
            } : null));
    }

    function imageFile(path, cb) {
        const ext = path.split(".").pop().toLowerCase();
        const mime = {
            png: "image/png",
            jpg: "image/jpeg",
            jpeg: "image/jpeg",
            webp: "image/webp",
            gif: "image/gif",
            bmp: "image/bmp"
        }[ext];
        if (!mime) {
            cb(null);
            return;
        }
        run(["base64", "-w0", path], (ok, b64) => cb(ok ? {
                type: "image",
                kind: "file",
                name: path.split("/").pop(),
                mimeType: mime,
                base64: b64.trim(),
                path: path
            } : null));
    }

    function file(path, cb) {
        const p = String(path || "").replace(/^file:\/\//, "");
        if (/\.(png|jpe?g|webp|gif|bmp)$/i.test(p)) {
            imageFile(p, cb);
            return;
        }
        // Text files are inlined (first 200 KB); binaries become a path reference.
        run(["sh", "-c", "if grep -Iq . \"$1\" 2>/dev/null || [ ! -s \"$1\" ]; then head -c 200000 \"$1\"; else exit 3; fi", "sh", p], (ok, text) => {
            if (ok)
                cb({
                    type: "text",
                    kind: "file",
                    name: p.split("/").pop(),
                    path: p,
                    text: text
                });
            else
                cb({
                    type: "text",
                    kind: "file",
                    name: p.split("/").pop(),
                    path: p,
                    text: "(binary file at " + p + ")"
                });
        });
    }

    function pickFile(cb) {
        run(["zenity", "--file-selection", "--title=Attach a file"], (ok, out) => {
            if (ok && out.trim())
                file(out.trim(), cb);
            else
                cb(null);
        });
    }

    function pickDirectory(start, cb) {
        run(["zenity", "--file-selection", "--directory", "--title=Project folder", "--filename=" + (start || Quickshell.env("HOME")) + "/"], (ok, out) => cb(ok ? out.trim() : ""));
    }

    function activeWindow(cb) {
        const c = YozdService.focusedClient;
        if (!c) {
            cb(null);
            return;
        }
        const app = c["class"] || c.app_id || c.initialClass || "";
        cb({
            type: "text",
            kind: "window",
            name: app || "window",
            text: "Active window: " + (c.title || "") + (app ? " (" + app + ")" : "")
        });
    }

    // What the user is looking at right now, for the Assistant's suggestion
    // chips (aicenter/assistant/Suggestions.js). Cheap reads only.
    function ambient() {
        const p = MprisController.activePlayer;
        const c = YozdService.focusedClient;
        const clip = (ClipboardService.items || [])[0];
        return {
            hour: new Date().getHours(),
            media: p && p.trackTitle ? {
                title: p.trackTitle,
                artist: p.trackArtist || "",
                playing: !!p.isPlaying
            } : null,
            window: c ? {
                appId: c["class"] || c.app_id || c.initialClass || "",
                title: c.title || ""
            } : null,
            clipboard: clip ? {
                text: clip.isImage || clip.isFile ? "" : (clip.fullContent || clip.preview || ""),
                isImage: !!clip.isImage
            } : null,
            timer: null
        };
    }

    function grab(kind, cb) {
        switch (kind) {
        case "selection":
            return selection(cb);
        case "clipboard":
            return clipboard(cb);
        case "region":
            return screenshot(true, cb);
        case "screen":
            return screenshot(false, cb);
        case "file":
            return pickFile(cb);
        case "window":
            return activeWindow(cb);
        }
        cb(null);
    }
}
