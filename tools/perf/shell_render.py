"""Offscreen render + frame-time harness for the unified shell panel.

usage: shell_render.py <repo-src-dir> <out-dir> [--configs=a,b] [--configs-file=F] [--bench]

Builds a qs.* import tree from <repo-src-dir> (the working tree, or a
`git archive <rev>` extraction to compare against), stubs Quickshell, loads
the real UnifiedShellPanel visual tree (PanelWindow-only lines stripped)
over a test wallpaper and renders each config of shell_render_configs.json
to <out-dir>/<name>.png. Compare two runs with render_diff.py.

A config may also post notifications: "notify": [{summary, body, appName,
urgency}] (sent through Notifications.notifyInternal after the other keys
apply, history cleared first) and "captureAt": [ms, ...] to also save
mid-animation frames (<name>-t<ms>.png); --configs-file reads the configs
from another JSON file (e.g. notify_render_configs.json).

--bench times full-window renders (grabWindow: render + readback) with no
change and with a 4 px change inside the notch; run it with
LP_NUM_THREADS=1 for stable llvmpipe numbers. The clock shows real time, so
two runs can differ in the clock text.

Runs under a private Xvfb (tests/lib/headless.py), never on the desktop.
"""
import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tests"))
from lib import headless  # noqa
headless.ensure(gl=True)
from PySide6.QtCore import QCoreApplication, QElapsedTimer, QUrl, QMetaObject, Qt, Q_ARG
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent
from PySide6.QtQuick import QQuickView

SRC = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]); OUT.mkdir(parents=True, exist_ok=True)
ARGS = sys.argv[3:]
W, H = 2560, 1440
app = QGuiApplication([])
tmp = Path(tempfile.mkdtemp(prefix="shellrender-"))
QS = tmp / "qs"

# Harness-only typing relaxations (import cycles Quickshell tolerates)
PATCHES = {
    "modules/bar/activities/ActivityHost.qml": [("required property BarContent bar", "required property var bar"), ("required property NotchContent notch", "required property var notch")],
}
SKIP = {".git", ".cache", "node_modules"}
for top in ["modules", "config", "assets"]:
    for d, dirs, files in os.walk(SRC / top):
        dirs[:] = [x for x in dirs if x not in SKIP]
        rel = Path(d).relative_to(SRC)
        tgt = QS / rel
        tgt.mkdir(parents=True, exist_ok=True)
        qml = []
        for f in files:
            srcf = Path(d) / f
            if f.endswith(".qml"):
                txt = srcf.read_text(errors="ignore")
                new = re.sub(r'^import "\./[^"]+\.qml"[^\n]*\n', "", txt, flags=re.M)
                for a, b in PATCHES.get(str(rel / f), []):
                    new = new.replace(a, b)
                if new != txt:
                    (tgt / f).write_text(new)
                    qml.append(f)
                    continue
            (tgt / f).symlink_to(srcf)
            if f.endswith(".qml"):
                qml.append(f)
        if qml and "qmldir" not in files:
            lines = ["module qs." + ".".join(rel.parts)]
            for f in sorted(qml):
                txt = (Path(d) / f).read_text(errors="ignore")
                single = re.search(r"^\s*pragma\s+Singleton\b", txt, re.M)
                lines.append(("singleton " if single else "") + f"{f[:-4]} 1.0 {f}")
            (tgt / "qmldir").write_text("\n".join(lines) + "\n")
(QS / "shell.qml").symlink_to(SRC / "shell.qml")

def module(name, files, extra=""):
    d = tmp / name.replace(".", "/")
    d.mkdir(parents=True, exist_ok=True)
    lines = ["module " + name]
    for n, body in files.items():
        single = body.lstrip().startswith("pragma Singleton")
        if "import QtQuick" not in body:
            body = ("pragma Singleton\n" if single else "") + "import QtQuick\n" + body.replace("pragma Singleton\n", "", 1)
        (d / f"{n}.qml").write_text(body)
        lines.append(("singleton " if single else "") + f"{n} 1.0 {n}.qml")
    (d / "qmldir").write_text("\n".join(lines) + "\n" + extra)

SCREEN = '{ "name": "DP-1", "width": %d, "height": %d, "x": 0, "y": 0, "devicePixelRatio": 1 }' % (W, H)
module("Quickshell", {
    "Quickshell": """pragma Singleton
QtObject {
    property var screens: [screenObj]
    // A real ShellScreen stub instance: typed `required property ShellScreen screen`
    // consumers (PanelHost, NotchContent) reject a plain QtObject (null screen = no bar).
    property ShellScreen screenObj: ShellScreen { name: "DP-1"; width: %d; height: %d; x: 0; y: 0; devicePixelRatio: 1 }
    property string shellDir: "%s"
    property string cacheDir: "%s/cache"
    property var cursor: null
    function env(n) { if (n === "HOME") return "%s"; return ""; }
    function execDetached(a) {}
    function iconPath(n, f) { return ""; }
    function cachePath(p) { return "%s/cache/" + p; }
    function dataPath(p) { return "%s/data/" + p; }
    function statePath(p) { return "%s/state/" + p; }
}""" % (W, H, QS, tmp, tmp, tmp, tmp, tmp),
    "Singleton": "QtObject { property string reloadableId; default property list<QtObject> data }",
    "ShellScreen": "QtObject { property string name; property int width; property int height; property int x; property int y; property real devicePixelRatio: 1 }",
    "Variants": "Item { property var model; property Component delegate }",
    "PanelWindow": "Item { property var screen; property color color; property var mask; property int exclusionMode; property int exclusiveZone; property var margins; property real implicitWidth; property real implicitHeight }",
    "PopupWindow": "Item { property PopupAnchor anchor: PopupAnchor {} property color color; property var mask; property bool grabFocus; property real implicitWidth; property real implicitHeight }",
    "PopupAnchor": "QtObject { property var window; property PopupRect rect: PopupRect {} property int edges; property int gravity; property var item; property bool adjustment; property PopupRect margins: PopupRect {} function updateAnchor() {} }",
    "PopupRect": "QtObject { property real x; property real y; property real width; property real height; property real left; property real right; property real top; property real bottom }",
    "FloatingWindow": "Item { property color color; property string title }",
    "Region": "QtObject { property var item; property list<QtObject> regions; property int intersection; property real x; property real y; property real width; property real height; property real radius }",
    "LazyLoader": "Item { property bool active; property bool loading; property Component component; property var item }",
    "ScriptModel": "QtObject { property var values; property var objectProp; readonly property var count: values ? values.length : 0 }",
    "ObjectModel": "QtObject { property var values: [] }",
    "SystemClock": "QtObject { property int precision; property date date: new Date(2026, 9, 5, 12, 34, 0); property int hours: 12; property int minutes: 34; property int seconds: 0 }",
    "ElapsedTimer": "QtObject { function restart() { return 0; } function elapsed() { return 0; } function elapsedMs() { return 0; } }",
    "PersistentProperties": "QtObject { property string reloadableId }",
    "QsMenuAnchor": "QtObject { property var menu; property var anchor; signal visibleChanged; function open() {} function close() {} }",
    "QsMenuOpener": "QtObject { property var menu; property var children: ({ values: [] }) }",
    "DesktopEntries": """pragma Singleton
QtObject { property var applications: ({ values: [] }); function heuristicLookup(n) { return null; } function byId(n) { return null; } }""",
    "QsWindow": "QtObject { property var window }",
    "Retainable": "QtObject {}",
    "BoundComponent": "Item { property var source; property var sourceComponent }",
    "EasingCurve": "QtObject { property var curve }",
    "ColorQuantizer": "QtObject { property var source; property int depth; property real rescaleSize; property var colors: [] }",
}, "")
module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running; property var environment; property bool clearEnvironment; property string workingDirectory; property var stdout; property var stderr; property bool stdinEnabled; property int processId; signal exited(int exitCode, int exitStatus); signal started; function write(d) {} function signal(s) {} function startDetached() {} }",
    "StdioCollector": "QtObject { property string text; property bool waitForEnd; signal streamFinished }",
    "SplitParser": "QtObject { property string splitMarker; signal read(string data) }",
    "FileView": """Item {
    property string path; property bool watchChanges; property bool atomicWrites; property bool blockLoading; property bool blockWrites; property bool blockAllReads; property bool printErrors; property bool preload: true
    property var adapter
    signal loaded; signal loadFailed(var error); signal fileChanged; signal adapterUpdated; signal saved; signal saveFailed(var error)
    function reload() {} function writeAdapter() {} function setText(t) {} function text() { return ""; } function data() { return ""; } function waitForJob() { return true; }
}""",
    "JsonAdapter": "QtObject { default property list<QtObject> data }",
    "JsonObject": "QtObject { default property list<QtObject> data }",
    "IpcHandler": "QtObject { property string target; property bool enabled }",
    "Socket": "QtObject { property string path; property bool connected; property var parser; signal error(var e); function write(d) {} function flush() {} }",
    "SocketServer": "QtObject { property string path; property bool active; property Component handler }",
    "DataStream": "QtObject {}",
    "DataStreamParser": "QtObject {}",
})
module("Quickshell.Wayland", {
    "WlrLayershell": "QtObject {}",
    "WlrLayer": "QtObject { enum Values { Background = 0, Bottom = 1, Top = 2, Overlay = 3 } }",
    "WlrKeyboardFocus": "QtObject { enum Values { None = 0, Exclusive = 1, OnDemand = 2 } }",
    "ExclusionMode": "QtObject { enum Values { Normal = 0, Ignore = 1, Auto = 2 } }",
    "ToplevelManager": "pragma Singleton\nQtObject { property var toplevels: ({ values: [] }); property var activeToplevel: null }",
    "WlSessionLock": "Item { property bool locked; property Component surface }",
    "WlSessionLockSurface": "Item { property color color; property var screen }",
    "ScreencopyView": "Item { property var captureSource; property bool live; property bool paintCursors; property bool hasContent }",
    "WlrLayershellStub": "QtObject {}",
})
module("Quickshell.Hyprland", {
    "Hyprland": "pragma Singleton\nQtObject { property var toplevels: ({ values: [] }); property var monitors: ({ values: [] }); property var workspaces: ({ values: [] }); property var focusedMonitor: null; signal rawEvent(var event); function refreshToplevels() {} function refreshMonitors() {} function refreshWorkspaces() {} function dispatch(d) {} }",
    "GlobalShortcut": "QtObject { property string name; property string description; property string appid; signal pressed; signal released }",
    "HyprlandFocusGrab": "QtObject { property var windows; property bool active; signal cleared }",
})
module("Quickshell.Widgets", {
    "IconImage": "Image { property real implicitSize; property bool asynchronous; property real alpha }",
    "ClippingRectangle": "Rectangle { property real contentInsideBorder; clip: true }",
    "ClippingWrapperRectangle": "Rectangle { property real margin; clip: true }",
    "WrapperItem": "Item { property real margin; property real leftMargin; property real rightMargin; property real topMargin; property real bottomMargin; property bool resizeChild }",
    "WrapperRectangle": "Rectangle { property real margin }",
    "WrapperMouseArea": "MouseArea { property real margin }",
    "MarginWrapperManager": "QtObject { property real margin }",
})
module("Quickshell.Services.Mpris", {"Mpris": "pragma Singleton\nQtObject { property var players: ({ values: [] }) }", "MprisPlaybackState": "QtObject { enum Values { Stopped = 0, Playing = 1, Paused = 2 } }", "MprisLoopState": "QtObject { enum Values { None = 0, Track = 1, Playlist = 2 } }"})
module("Quickshell.Services.Pipewire", {"Pipewire": "pragma Singleton\nQtObject { property var nodes: ({ values: [] }); property var defaultAudioSink: null; property var defaultAudioSource: null; property var preferredDefaultAudioSink; property var preferredDefaultAudioSource; property bool ready }", "PwObjectTracker": "QtObject { property var objects }", "PwNodeLinkTracker": "QtObject { property var node; property var linkGroups: [] }", "PwNodeType": "QtObject { enum Values { Dummy } }"})
module("Quickshell.Services.SystemTray", {"SystemTray": "pragma Singleton\nQtObject { property var items: ({ values: [] }) }", "SystemTrayItem": "QtObject {}", "Status": "QtObject { enum Values { Passive = 0, Active = 1, NeedsAttention = 2 } }"})
module("Quickshell.Services.UPower", {"UPower": "pragma Singleton\nQtObject { property var displayDevice: QtObject { property bool isLaptopBattery: false; property bool ready: false; property real percentage: 1; property int state: 0 } property bool onBattery: false }", "UPowerDeviceState": "QtObject { enum Values { Charging = 1, Discharging = 2, FullyCharged = 4 } }", "PowerProfiles": "pragma Singleton\nQtObject { property int profile; property bool hasPerformanceProfile }", "PowerProfile": "QtObject { enum Values { PowerSaver = 0, Balanced = 1, Performance = 2 } }"})
module("Quickshell.Services.Notifications", {"Notification": "QtObject { property int id; property string appName; property string summary; property string body; property string appIcon; property string image; property var actions: []; property int urgency; property bool tracked; property bool transient; property var hints; property real expireTimeout; property string desktopEntry; property bool resident; signal closed(var reason); function dismiss() {} function expire() {} }", "NotificationAction": "QtObject { property string identifier; property string text; function invoke() {} }","NotificationServer": "QtObject { property bool keepOnReload; property bool actionsSupported; property bool bodySupported; property bool imageSupported; property bool persistenceSupported; property bool bodyMarkupSupported; property bool bodyHyperlinksSupported; property bool bodyImagesSupported; property bool actionIconsSupported; property bool inlineReplySupported; property var trackedNotifications: ({ values: [] }); signal notification(var n) }", "NotificationUrgency": "QtObject { enum Values { Low = 0, Normal = 1, Critical = 2 } }", "NotificationCloseReason": "QtObject { enum Values { Dummy } }"})
module("Quickshell.Services.Pam", {"PamContext": "QtObject {}", "PamResult": "QtObject { enum Values { Dummy } }"})

# The panel: real UnifiedShellPanel.qml minus PanelWindow-only lines
src = (SRC / "modules/shell/UnifiedShellPanel.qml").read_text()
src = re.sub(r"\n    anchors \{\n(        \w+: true\n)+    \}\n", "\n", src)
src = re.sub(r"\n    WlrLayershell\.keyboardFocus: \{.*?\n    \}\n", "\n", src, flags=re.S)
src = re.sub(r"\n\s*WlrLayershell\.[^\n]*", "", src)
src = re.sub(r"\n\s*exclusionMode:[^\n]*", "", src)
(QS / "modules/shell/UnifiedShellPanel.qml").unlink()
(QS / "modules/shell/UnifiedShellPanel.qml").write_text(src)

stage = tmp / "Stage.qml"
stage.write_text(f"""import QtQuick
import Quickshell
import qs.config
import qs.modules.shell
import qs.modules.services
import qs.modules.theme
Item {{
    id: stage
    width: {W}; height: {H}
    property var screenObj: Quickshell.screens[0]
    // Test wallpaper: smooth gradient + checker so shadows/edges show up
    Rectangle {{
        anchors.fill: parent
        gradient: Gradient {{ GradientStop {{ position: 0; color: "#c9d6df" }} GradientStop {{ position: 1; color: "#52616b" }} }}
    }}
    Grid {{
        anchors.fill: parent; columns: 40; opacity: 0.08
        Repeater {{ model: 40 * 23; Rectangle {{ width: 64; height: 64; color: (index + Math.floor(index / 40)) % 2 ? "black" : "white" }} }}
    }}
    Loader {{
        id: panelLoader
        anchors.fill: parent
        active: false
        sourceComponent: Component {{ UnifiedShellPanel {{ targetScreen: stage.screenObj; width: {W}; height: {H} }} }}
    }}
    property alias panel: panelLoader.item
    function load() {{ panelLoader.active = true; }}
    function unload() {{ panelLoader.active = false; }}
    function setCfg(path, value) {{
        if (path === "bar.layout.style") {{ Config.bar.layout = Object.assign({{}}, Config.bar.layout, {{ style: value }}); return; }}
        const parts = path.split(".");
        let o = Config;
        for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]];
        o[parts[parts.length - 1]] = value;
    }}
    function getCfg(path) {{
        const parts = path.split(".");
        let o = Config;
        for (let i = 0; i < parts.length; i++) o = o[parts[i]];
        return o;
    }}
    function ready() {{
        for (const k of ["themeReady","barReady","workspacesReady","overviewReady","notchReady","compositorReady","performanceReady","weatherReady","desktopReady","lockscreenReady","prefixReady","systemReady","dockReady","aiReady","generalReady","voiceReady","notificationsReady","appsReady"]) Config[k] = true;
    }}
    function setPos(p) {{ Config.bar.position = p; }}
    function notify(n) {{ Notifications.notifyInternal(n); }}
    function clearNotifications() {{ Notifications.discardAllNotifications(); }}
    property Item probe: null
    // Bench: recolour a 4 px probe inside the notch (a "small change")
    function tick(x) {{
        if (!probe) {{
            let n = null;
            const walk = it => {{ if (n || !it) return; if (it.notchContainerRef !== undefined) {{ n = it.notchContainerRef; return; }} for (let i = 0; i < it.children.length; i++) walk(it.children[i]); }};
            walk(panel);
            probe = Qt.createQmlObject('import QtQuick; Rectangle {{ width: 4; height: 4; x: 40; y: 10; z: 100 }}', n);
        }}
        probe.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1);
    }}
}}
""")

STUB_ROOTS = [tmp / "Quickshell"]
NOPROP = re.compile(r'(file://\S+?):(\d+):(\d+): Cannot assign to non-existent property "(\w+)"')
NOTYPE = re.compile(r'(file://\S+?):(\d+):(\d+): (\w+) is not a type')
def enclosing(path, line, col):
    lines = Path(path).read_text().split("\n")
    text = "\n".join(lines[:line - 1] + [lines[line - 1][:col - 1]])
    depth = 0
    for i in range(len(text) - 1, -1, -1):
        if text[i] == "}": depth += 1
        elif text[i] == "{":
            if depth == 0:
                m = re.search(r"([A-Z]\w*)\s*$", text[:i]); return m.group(1) if m else ""
            depth -= 1
    return ""
def find_stub(name):
    for r in STUB_ROOTS:
        for f in r.rglob(name + ".qml"):
            return f
    return None
def autofix(errors):
    changed = False
    for url, line, col, prop in NOPROP.findall(errors):
        t = enclosing(QUrl(url).toLocalFile(), int(line), int(col))
        f = find_stub(t)
        if not f:
            continue
        body = f.read_text()
        decl = (f"signal {prop[2].lower()}{prop[3:]}()" if re.match(r"on[A-Z]", prop) else f"property var {prop}")
        if decl in body:
            continue
        i = body.index("{", body.index(re.search(r"\n(Item|QtObject|Image|Rectangle|MouseArea)\s*\{", "\n" + body.split("import QtQuick\n",1)[-1]).group(1)))
        f.write_text(body[:i + 1] + " " + decl + ";" + body[i + 1:])
        print("autofix", t, decl, file=sys.stderr)
        changed = True
    for url, _line, _col, typ in NOTYPE.findall(errors):
        path = Path(QUrl(url).toLocalFile())
        mods = re.findall(r"^import (Quickshell[\w.]*)\s*$", path.read_text(), re.M)
        if not mods:
            continue
        mods.sort(key=len, reverse=True)
        d = tmp / mods[0].replace(".", "/")
        if (d / (typ + ".qml")).exists():
            continue
        (d / (typ + ".qml")).write_text("import QtQuick\nItem {}\n")
        with open(d / "qmldir", "a") as q:
            q.write(f"{typ} 1.0 {typ}.qml\n")
        print("autostub", mods[0], typ, file=sys.stderr)
        changed = True
    return changed

engine = QQmlEngine()
engine.addImportPath(str(tmp))
# Compile (and auto-stub) the pieces one by one first, so a failure names
# the piece instead of the whole panel.
_warm = []
WARM = [("qs.modules.notch", "NotchContent"), ("qs.modules.bar", "BarContent"), ("qs.modules.dock", "DockContent"), ("qs.modules.frame", "ScreenFrameContent"), ("qs.modules.bar.activities", "ActivityHost")]
# Bar panel styles are loaded by URL at runtime (BarContent.loadStyle), so
# warm them too: otherwise a missing stub only shows up as an empty bar.
WARM += [("qs.modules.bar.panels.styles", f.stem) for f in sorted((SRC / "modules/bar/panels/styles").glob("*.qml"))]
for mod, typ in WARM:
    (tmp / f"Warm{typ}.qml").write_text(f"import QtQuick\nimport {mod}\nItem {{ property Component c: Component {{ {typ} {{}} }} }}\n")
for _mod, typ in WARM:
    f = tmp / f"Warm{typ}.qml"
    for _attempt in range(40):
        c = QQmlComponent(engine, QUrl.fromLocalFile(str(f)))
        if c.status() == QQmlComponent.Ready:
            _warm.append(c); break
        if not autofix("\n".join(e.toString() for e in c.errors())):
            print("warm failed", typ, "\n".join(e.toString() for e in c.errors())); break
        engine.clearComponentCache()
view = QQuickView(engine, None)
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(W, H)
for _attempt in range(60):
    view.setSource(QUrl.fromLocalFile(str(stage)))
    if view.status() == QQuickView.Ready:
        break
    errs = "\n".join(e.toString() for e in view.errors())
    if not autofix(errs):
        print(errs)
        sys.exit(1)
    engine.clearComponentCache()
    view.setSource(QUrl())
    engine.clearComponentCache()
else:
    sys.exit(1)
view.show()
root = view.rootObject()

def pump(ms):
    t = QElapsedTimer(); t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents(); time.sleep(0.002)

def call(name, *args):
    QMetaObject.invokeMethod(root, name, Qt.DirectConnection, *[Q_ARG("QVariant", a) for a in args])

def setcfg(path, value):
    call("setCfg", path, value)

call("ready")
configs_file = Path(__file__).with_name("shell_render_configs.json")
sel = None
for a in ARGS:
    if a.startswith("--configs="):
        sel = a.split("=", 1)[1].split(",")
    if a.startswith("--configs-file="):
        configs_file = Path(a.split("=", 1)[1])
CONFIGS = json.loads(configs_file.read_text())
call("load")
pump(1500)
for name, cfg in CONFIGS.items():
    if sel and name not in sel:
        continue
    for k, v in cfg.items():
        if k not in ("notify", "captureAt"):
            setcfg(k, v)
    pump(1200)
    if "notify" in cfg:
        call("clearNotifications")
        pump(600)
        for n in cfg["notify"]:
            call("notify", n)
        elapsed = 0
        for t in cfg.get("captureAt", []):
            pump(t - elapsed)
            elapsed = t
            view.grabWindow().save(str(OUT / f"{name}-t{t}.png"))
        pump(1200)
    img = view.grabWindow()
    img.save(str(OUT / f"{name}.png"))
    print("rendered", name, flush=True)

if "--bench" in ARGS:
    for k, v in CONFIGS["bench"].items():
        setcfg(k, v)
    pump(1000)

    def measure(label, fn, n=40):
        d = []
        for _ in range(n):
            fn()
            QCoreApplication.processEvents()
            a = time.perf_counter()
            view.grabWindow()
            d.append(time.perf_counter() - a)
        d.sort()
        print(f"bench {label}: median_ms={1000 * d[len(d) // 2]:.1f} p90_ms={1000 * d[int(len(d) * 0.9)]:.1f}", flush=True)

    call("tick", 0)
    measure("idle (no change)", lambda: None)
    measure("small notch change", lambda: call("tick", 0))
sys.stdout.flush(); sys.stderr.flush()
os._exit(0)
