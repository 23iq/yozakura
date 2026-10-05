import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import "../FileQuery.js" as FileQuery

// Files and folders in $HOME through fd or plocate (whichever is installed,
// prefix.launcher.fileBackend), excludes from prefix.launcher.fileExcludes.
// Debounced; a new query kills the running one. Enter opens, options:
// reveal in the file manager, copy the path.
LauncherProvider {
    id: files

    mixedLimit: 4
    readonly property var cfg: Config.prefix.launcher
    readonly property string home: Brand.home
    property var tools: ({})
    property bool detected: false
    readonly property string kind: FileQuery.backend(cfg.fileBackend, tools)
    property string pending: ""

    property Process detect: Process {
        running: true
        command: ["sh", "-c", "for t in fd fdfind plocate; do command -v \"$t\" >/dev/null 2>&1 && echo \"$t\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = {};
                text.split("\n").forEach(l => {
                    if (l === "fd" || l === "fdfind")
                        t.fd = t.fd || l;
                    else if (l === "plocate")
                        t.plocate = true;
                });
                files.tools = t;
                files.detected = true;
                if (files.mode !== "")
                    files.search(files.query, files.mode);
            }
        }
    }

    property Timer debounce: Timer {
        interval: 180
        onTriggered: files.run()
    }

    // Query of the running process (stale output is dropped).
    property string running: ""

    property Process proc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (files.running !== files.pending)
                    return;
                const limit = files.mode === "prefix" ? files.cfg.fileMaxResults : files.mixedLimit;
                const found = FileQuery.parse(text, files.pending, files.home, files.cfg.fileExcludes, limit);
                files.busy = false;
                files.results = found.length > 0 ? found.map(f => files.row(f)) : (files.mode === "prefix" ? [files.infoRow("launcher.files.none", "")] : []);
            }
        }
    }

    function search(text, searchMode) {
        files.query = text;
        files.mode = searchMode;
        const q = (text || "").trim();
        const wanted = searchMode === "prefix" || (searchMode === "mixed" && files.cfg.filesInMixed && q.length >= 3);
        if (!wanted || q === "") {
            files.pending = "";
            files.debounce.stop();
            files.busy = false;
            files.results = searchMode === "prefix" ? [files.infoRow("launcher.files.hint", "launcher.files.hint.desc")] : [];
            return;
        }
        if (files.detected && files.kind === "") {
            files.results = searchMode === "prefix" ? [files.infoRow("launcher.files.missing", "launcher.files.missing.desc")] : [];
            return;
        }
        files.pending = q;
        files.busy = true;
        files.debounce.restart();
    }

    function run() {
        if (!files.detected || files.pending === "")
            return;
        const limit = files.mode === "prefix" ? files.cfg.fileMaxResults : 10;
        const argv = FileQuery.command(files.kind, files.pending, files.home, files.cfg.fileExcludes, limit, files.tools);
        if (!argv)
            return;
        files.proc.running = false;
        files.running = files.pending;
        files.proc.command = argv;
        files.proc.running = true;
    }

    function infoRow(title, desc) {
        return {
            "key": "info",
            "title": I18n.t(title),
            "subtitle": desc ? I18n.t(desc).replace("%1", files.home.replace(Brand.home, "~")) : "",
            "icon": Icons.magnifyingGlass,
            "inert": true
        };
    }

    function row(f) {
        return {
            "key": f.path,
            "title": f.name,
            "subtitle": FileQuery.pretty(f.dir, files.home),
            "icon": Icons[FileQuery.iconName(f)] || Icons.file,
            "badge": I18n.t(f.isDir ? "launcher.files.folder" : "launcher.files.file"),
            "hint": I18n.t("launcher.open"),
            "data": f
        };
    }

    function activate(item, option) {
        const f = item.data;
        if (item.inert || !f)
            return false;
        if (option === "copy") {
            Quickshell.execDetached(["wl-copy", "--", f.path]);
            return true;
        }
        if (option === "reveal") {
            // FileManager1 selects the file in Nautilus/Dolphin/Thunar...;
            // without one, open the parent folder.
            Quickshell.execDetached(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems \"['file://$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"", "sh", f.path, f.dir]);
            return true;
        }
        Quickshell.execDetached(["xdg-open", f.path]);
        return true;
    }

    function options(item) {
        if (item.inert)
            return [];
        return [
            {
                "id": "",
                "text": I18n.t("launcher.open"),
                "icon": Icons.arrowSquareOut,
                "variant": "primary"
            },
            {
                "id": "reveal",
                "text": I18n.t("launcher.files.reveal"),
                "icon": Icons.folderOpen,
                "variant": "secondary"
            },
            {
                "id": "copy",
                "text": I18n.t("launcher.files.copy_path"),
                "icon": Icons.copy,
                "variant": "tertiary"
            }
        ];
    }
}
