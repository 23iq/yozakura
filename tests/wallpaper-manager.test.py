"""The Wallpaper manager's helper components, offscreen with fake processes.

Wallpaper.qml (a PanelWindow) delegates its background work to
WallpaperScanner (file/subfolder scans, fallback, saved selection),
WallpaperColorPresets (preset list + apply), MatugenRunner and
WallpaperCacheJobs (thumbnails, lock screen frame). Process/FileView are
stubbed: each started process is recorded and the test feeds its output.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness("wallpaper-manager")
h.module("Quickshell", {"Scope": "import QtQuick\nQtObject { default property list<QtObject> data }"})
h.module("Quickshell.Io", {
    "Process": """import QtQuick
import qs.modules.globals
QtObject {
    id: proc
    property var command: []
    property bool running: false
    property QtObject stdout
    property QtObject stderr
    property int starts: 0
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) { starts++; ProcLog.started(proc); }
    // Test helper: deliver output, then the process ends.
    function finish(out, code) {
        if (stdout) { stdout.text = out; stdout.streamFinished(); }
        running = false;
        exited(code, 0);
    }
}""",
    "StdioCollector": "import QtQuick\nQtObject { property string text; signal streamFinished() }",
    "FileView": """import QtQuick
QtObject { property string path; property bool watchChanges; property bool printErrors; property int reloads: 0
    signal fileChanged()
    function reload() { reloads++; } }""",
})
h.module("qs.modules.globals", {
    "Brand": "pragma Singleton\nimport QtQuick\nQtObject { property string configDir: '/cfg'; "
             "property string cacheDir: '/cache'; property string appId: 'app'; property string appBin: 'app' }",
    "GlobalStates": "pragma Singleton\nimport QtQuick\nQtObject { property var wallpaperManager: null }",
    "ProcLog": """pragma Singleton
import QtQuick
QtObject {
    property var procs: []
    function started(p) { if (procs.indexOf(p) < 0) procs = procs.concat([p]); }
    // Last started process whose command contains `needle`.
    function find(needle) {
        for (var i = procs.length - 1; i >= 0; i--)
            if (procs[i].running && JSON.stringify(procs[i].command).indexOf(needle) >= 0) return procs[i];
        return null;
    }
}""",
})
for f in ["WallpaperScanner", "WallpaperColorPresets", "MatugenRunner", "WallpaperCacheJobs"]:
    h.copy(f"modules/widgets/dashboard/wallpapers/{f}.qml", siblings=False)

root = h.load("""import QtQuick
import qs.modules.globals
Item {
    QtObject {
        id: manager
        property string wallpaperDir: "/w"
        property var scanDirs: ["/w"]
        property var extraDirs: []
        property string fallbackDir: "/fallback"
        property var wallpaperPaths: []
        property var subfolderFilters: []
        property var allSubdirs: []
        property int currentIndex: -1
        property bool initialLoadCompleted: false
        property bool usingFallback: false
        property int thumbs: 0
        function refreshFolders() {}
    }
    QtObject { id: adapter; property string currentWall: "/w/b.jpg" }
    property alias manager: manager
    property alias adapter: adapter
    property alias jobs: jobs
    property alias scanner: scanner
    property alias presets: presets
    property alias matugen: matugen
    WallpaperCacheJobs { id: jobs; fallbackDir: "/fallback"; onThumbnailsGenerated: manager.thumbs++ }
    WallpaperScanner { id: scanner; manager: manager; adapter: adapter; jobs: jobs }
    WallpaperColorPresets { id: presets }
    MatugenRunner { id: matugen }
}""", auto_stub=False)
ok = True


def check(name, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + name + (" " + detail if detail else ""))


def ev(expr):
    return h.eval(root, expr)


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


# --- scanner: main folder, saved selection, thumbnails --------------------
ev('scanner.scan(["/w"])')
check("scan runs find over the folder", ev('ProcLog.find("/w") !== null'))
ev('ProcLog.find("/w").finish("/w/c.jpg\\n/w/b.jpg\\n/w/a.png\\n", 0)')
check("paths are sorted", js("manager.wallpaperPaths") == ["/w/a.png", "/w/b.jpg", "/w/c.jpg"])
check("saved wallpaper is selected", ev("manager.currentIndex") == 1)
check("initial load completes", ev("manager.initialLoadCompleted") is True)
pump(2300)
check("thumbnails are regenerated (debounced)", ev('ProcLog.find("thumbs") !== null'),
      str(js("ProcLog.procs.map(p => p.command)")))
check("thumbnail command carries the fallback folder", js('ProcLog.find("thumbs").command')[:5]
      == ["app", "thumbs", "/cache/wallpapers.json", "/cache", "/fallback"])
ev('ProcLog.find("thumbs").finish("", 0)')
check("thumbnailsGenerated after a successful run", ev("manager.thumbs") == 1)

# --- scanner: empty folder -> fallback -----------------------------------
ev('manager.wallpaperPaths = []; manager.initialLoadCompleted = false; adapter.currentWall = ""')
ev('scanner.scan(["/w"])')
ev('ProcLog.find("/w").finish("", 0)')
check("empty folder switches to the fallback", ev("manager.usingFallback") is True)
ev('ProcLog.find("/fallback").finish("/fallback/z.jpg\\n/fallback/y.jpg\\n", 0)')
check("fallback paths are used", js("manager.wallpaperPaths") == ["/fallback/y.jpg", "/fallback/z.jpg"])
check("first fallback wallpaper is saved", ev("adapter.currentWall") == "/fallback/y.jpg" and ev("manager.currentIndex") == 0)

# --- scanner: subfolders --------------------------------------------------
ev('scanner.scanSubfolders("/w")')
ev('ProcLog.find("-type\\",\\"d").finish("/w/b\\n/w/a\\n/w/a/deep\\n", 0)')
check("top-level subfolders become filters", js("manager.subfolderFilters") == ["a", "b"])
check("all subdirs are watched", js("manager.allSubdirs") == ["/w/b", "/w/a", "/w/a/deep"])

# --- colour presets --------------------------------------------------------
ev("presets.scan()")
ev('ProcLog.find("-maxdepth").finish("/a/colors/Nord\\n/cfg/colors/Nord\\n/cfg/colors/Dracula\\n", 0)')
check("preset names are deduplicated and sorted", js("presets.names") == ["Dracula", "Nord"])
check("user presets live in the config dir", ev("presets.userDir") == "/cfg/colors")
check("official presets live in assets/colors", ev("presets.officialDir").endswith("/assets/colors"))
ev('presets.apply("Nord", true)')
cmd = js('ProcLog.find("light.json").command')
check("apply copies the light variant over the palette",
      cmd[:2] == ["sh", "-c"] and "Nord" not in cmd[2] and cmd[4].endswith("/assets/colors/Nord/light.json")
      and cmd[5] == "/cfg/colors/Nord/light.json" and cmd[6] == "/cache/colors.json", str(cmd))

# --- matugen ---------------------------------------------------------------
ev('matugen.run("/w/a.png", "scheme-content", true)')
runs = [c for c in js("ProcLog.procs.filter(p => p.running).map(p => p.command)") if c and c[0] == "matugen"]
check("matugen runs twice (with and without config)", len(runs) == 2, str(runs))
with_cfg = [c for c in runs if "-c" in c]
check("config run uses assets/matugen/config.toml",
      len(with_cfg) == 1 and with_cfg[0][with_cfg[0].index("-c") + 1].endswith("/assets/matugen/config.toml"))
check("scheme and light mode are passed", all(c[c.index("-t") + 1] == "scheme-content" and c[-2:] == ["-m", "light"]
                                               for c in runs))

# --- lock screen frame -----------------------------------------------------
ev('jobs.generateLockscreenFrame("/w/v.mp4")')
check("lock screen frame command", js('ProcLog.find("lockwall").command') == ["app", "lockwall", "/w/v.mp4", "/cache"])

h.exit(0 if ok else 1)
