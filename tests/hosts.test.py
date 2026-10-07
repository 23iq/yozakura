"""Launcher/dashboard hosts (modules/shell/hosts): spotlight and sheet open on
the focused screen only, take focus, close on Escape and click outside, never
cover the bar on any edge, and open instantly with animations off."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QElapsedTimer, QPointF, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
h = Harness("hosts")

h.module("Quickshell", {
    "Scope": "Item {}",
    "Singleton": "QtObject {}",
    "ShellScreen": "QtObject { property string name; property int width; property int height }",
})
h.singleton("Quickshell", "Quickshell", 'QtObject { property var screens: [{name: "A"}, {name: "B"}] }')
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject layout: QtObject {
        property QtObject launcher: QtObject { property string host: "spotlight" }
        property QtObject dashboard: QtObject { property string host: "sheet" }
        property QtObject sheet: QtObject { property string side: "auto" }
        property QtObject cheatsheet: QtObject { property string host: "sheet" }
    }
    property QtObject bar: QtObject { property string position: "top"; property bool frameEnabled: false }
    property QtObject dock: QtObject { property string position: "bottom"; property int height: 64; property bool enabled: true }
    property QtObject notch: QtObject { property string position: "top" }
}""")
h.module("qs.modules.globals", {})
h.module("qs.modules.theme", {
    "Motion": """pragma Singleton
QtObject {
    property int d: Config.animDuration
    property QtObject enter: QtObject { property int duration: Motion.d; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject exit: QtObject { property int duration: Math.round(Motion.d * 0.7); property int easing: Easing.OutCubic; property real overshoot: 1 }
}""",
    "Metrics": "pragma Singleton\nQtObject { property int padding: 16; property int sheetW: 420 }",
    "BarMetrics": "pragma Singleton\nQtObject { property int moduleSize: 40; property int notchRestHeight: 36 }",
    "Colors": "pragma Singleton\nQtObject { property color scrim: '#000000' }",
    "Styling": "pragma Singleton\nQtObject { function radius(o) { return 16 + o; } }",
})
for f in ("Motion", "Metrics", "BarMetrics"):
    p = h.root / "qs/modules/theme" / f"{f}.qml"
    p.write_text("import qs.config\n" + p.read_text())
h.module("qs.modules.components", {"StyledRect": "Item { property string variant; property real radius; property bool enableShadow }", "Shadow": "Item {}"})
h.module("qs.modules.services", {"FocusGrab": "QtObject { property var windows; property bool active; signal cleared }"})
h.singleton("qs.modules.services", "Visibilities", """QtObject {
    id: vroot
    property Component flags: Component { QtObject { property bool launcher; property bool dashboard; property bool powermenu; property bool tools; property bool aiquick; property bool keybinds } }
    property string focused: "A"
    property var screens: ({})
    function getForScreen(n) {
        if (!screens[n])
            screens[n] = flags.createObject(vroot);
        return screens[n];
    }
    function setActiveModule(m) {
        for (const k in screens) { screens[k].launcher = false; screens[k].dashboard = false; screens[k].keybinds = false; }
        if (m) getForScreen(focused)[m] = true;
    }
}""")
VIEW = "Item { objectName: 'view'; focus: true; implicitWidth: 464; implicitHeight: 296; property string screenName }"
h.module("qs.modules.widgets.launcher", {"LauncherView": VIEW})
h.module("qs.modules.widgets.dashboard", {"DashboardView": VIEW.replace("464", "900")})
h.module("qs.modules.keybinds", {"CheatsheetView": VIEW.replace("'view'", "'cheatsheet'")})

h.copy("modules/shell/EdgeService.qml", "qs/modules/shell")
h.module("qs.modules.shell", {})

src = (REPO / "modules/shell/hosts/SurfaceHost.qml").read_text()
item = src.replace("import Quickshell.Wayland\n", "").replace("PanelWindow {", "Item {\n    property var screen\n    width: 1920\n    height: 1080", 1)
item = re.sub(r"\n    anchors \{[^}]*\}", "", item, count=1)
item = "\n".join(ln for ln in item.split("\n") if not re.match(r'\s*(color: "transparent"|exclusionMode:|WlrLayershell\.)', ln))
HOSTS = "qs/modules/shell/hosts"
h.copy("modules/shell/hosts/SurfaceHost.qml", HOSTS, replace={src: item})
for f in ("HostFrame", "SpotlightHost", "SheetHost", "HostRouter", "HostedSurfaces", "NotchHost", "NotchHostedSurfaces"):
    h.copy(f"modules/shell/hosts/{f}.qml", HOSTS, replace={"layer.enabled: true": "layer.enabled: false"})
h.module("qs.modules.shell.hosts", {})

root = h.load("""import QtQuick
import QtQuick.Window
import Quickshell
import qs.modules.shell.hosts
import qs.config
import qs.modules.services
Window {
    width: 1920; height: 1080; visible: true
    property ShellScreen a: ShellScreen { name: "A"; width: 1920; height: 1080 }
    property ShellScreen b: ShellScreen { name: "B"; width: 1920; height: 1080 }
    HostedSurfaces { objectName: "hsA"; screen: a }
    HostedSurfaces { objectName: "hsB"; screen: b }
    Item {
        id: container
        objectName: "notchContainer"
        property int pushes: 0
        property bool isShowingDefault: true
        property bool isShowingNotifications: false
        property QtObject stackView: QtObject {
            property int depth: 1
            property Item currentItem: null
            function pop() { depth = 1; currentItem = null; }
        }
        function pushView(v) { pushes++; stackView.depth++; stackView.currentItem = v; }
    }
    NotchHostedSurfaces { objectName: "nhA"; screen: a; vis: Visibilities.getForScreen("A"); container: container }
    Item {
        id: otherContainer
        property bool isShowingDefault: true
        property bool isShowingNotifications: false
        property QtObject stackView: QtObject { property int depth: 1; property Item currentItem: null; function pop() { depth = 1; currentItem = null; } }
        function pushView(v) { stackView.depth++; stackView.currentItem = v; }
    }
    NotchHostedSurfaces { objectName: "nhB"; screen: b; vis: Visibilities.getForScreen("B"); container: otherContainer }
}""", auto_stub=False)
root.requestActivate()
vis = h.eval(root, "Visibilities")
hsA, hsB = h.find(root, "hsA"), h.find(root, "hsB")


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


def ev(obj, expr):
    return h.eval(obj, expr)


def set_bar(edge):
    h.eval(root, f'Config.bar.position = "{edge}"')


def frame_rect(host, name):
    f = h.find(host, name)
    p = h.eval(f, "mapToItem(null, 0, 0)")
    return {"x": p.x(), "y": p.y(), "w": f.property("width"), "h": f.property("height")}


def overlaps(a, b):
    return a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]


BAR = {"top": {"x": 0, "y": 0, "w": 1920, "h": 40}, "bottom": {"x": 0, "y": 1040, "w": 1920, "h": 40},
       "left": {"x": 0, "y": 0, "w": 40, "h": 1080}, "right": {"x": 1880, "y": 0, "w": 40, "h": 1080}}

for edge in ("top", "bottom", "left", "right"):
    set_bar(edge)
    for module, host_prop, frame in (("launcher", "spotlight", "spotlightFrame"), ("dashboard", "sheet", "sheetFrame")):
        tag = f"{edge}/{module}"
        h.eval(root, f'Visibilities.setActiveModule("{module}")')
        host = ev(hsA, host_prop)
        assert host is not None, tag
        # animDuration 0: open at once, nothing stuck half-way
        assert ev(host, "isOpen") and ev(host, "progress") == 1, tag
        assert h.find(host, frame).property("opacity") == 1, tag
        assert ev(hsB, host_prop) is None or not ev(ev(hsB, host_prop), "isOpen"), f"{tag}: other screen"
        pump(10)
        assert ev(host, "view.activeFocus"), f"{tag}: focus"
        r = frame_rect(host, frame)
        assert not overlaps(r, BAR[edge]), f"{tag}: covers the bar {r}"
        assert r["x"] >= 0 and r["y"] >= 0 and r["x"] + r["w"] <= 1920 and r["y"] + r["h"] <= 1080, tag
        if module == "dashboard":
            assert ev(host, "side") == ("left" if edge == "right" else "right"), tag
            assert r["w"] == 900 + 2 * 16, tag  # view wider than Metrics.sheetW
        # Escape from the focused view closes through Visibilities
        QTest.keyClick(root, Qt.Key_Escape)
        pump(10)
        assert not ev(host, "isOpen") and not ev(host, "visible"), f"{tag}: escape"
        assert not ev(vis, f'getForScreen("A").{module}'), tag

# Click outside (on the scrim) closes; a click on the frame does not.
set_bar("top")
h.eval(root, 'Visibilities.setActiveModule("launcher")')
spot = ev(hsA, "spotlight")
QTest.mouseClick(root, Qt.LeftButton, Qt.NoModifier, QPointF(960, 540).toPoint())
pump(10)
assert ev(spot, "isOpen"), "click inside closed the spotlight"
QTest.mouseClick(root, Qt.LeftButton, Qt.NoModifier, QPointF(20, 1000).toPoint())
pump(10)
assert not ev(spot, "isOpen"), "click outside kept the spotlight open"

# Focused screen B: only B's host opens; closing it leaves A alone.
h.eval(root, 'Visibilities.focused = "B"; Visibilities.setActiveModule("launcher")')
assert ev(ev(hsB, "spotlight"), "isOpen") and not ev(spot, "isOpen")
h.eval(root, 'Visibilities.setActiveModule("")')
assert not ev(ev(hsB, "spotlight"), "isOpen")

# Animated: spotlight scales 0.96 -> 1, then closes fully (no stuck opacity).
h.eval(root, 'Visibilities.focused = "A"; Config.animDuration = 200; Visibilities.setActiveModule("launcher")')
f = h.find(spot, "spotlightFrame")
assert f.property("scale") < 1 and f.property("opacity") < 1
pump(400)
assert ev(spot, "progress") == 1 and abs(f.property("scale") - 1) < 1e-6
h.eval(root, 'Visibilities.setActiveModule("")')
pump(400)
assert ev(spot, "progress") == 0 and not ev(spot, "visible")

# The keybind cheatsheet routes through layout.cheatsheet.host ("keybinds" flag).
h.eval(root, 'Config.animDuration = 0; Visibilities.setActiveModule("keybinds")')
sheet = ev(hsA, "sheet")
assert ev(sheet, "isOpen") and ev(sheet, "view.objectName") == "cheatsheet", "cheatsheet in the sheet"
h.eval(root, 'Visibilities.setActiveModule("")')
assert not ev(sheet, "isOpen")
h.eval(root, 'Config.layout.cheatsheet.host = "fullscreen"; Visibilities.setActiveModule("keybinds")')
assert not ev(sheet, "isOpen") and not ev(spot, "isOpen"), "fullscreen is the cheatsheet window"
h.eval(root, 'Visibilities.setActiveModule("")')

# Unknown host falls back to the notch: nothing opens here.
h.eval(root, 'Config.layout.launcher.host = "bogus"; Visibilities.setActiveModule("launcher")')
assert not ev(spot, "isOpen")
# Rerouting the already-open module must push/pop the notch without changing flags.
h.eval(root, 'Config.layout.launcher.host = "spotlight"; Visibilities.focused = "A"; Visibilities.setActiveModule("launcher")')
pump(10)
nhA, nhB = h.find(root, "nhA"), h.find(root, "nhB")
c = h.find(root, "notchContainer")
for module, outside in (("launcher", "spotlight"), ("dashboard", "sheet")):
    h.eval(root, f'Config.layout.{module}.host = "{outside}"; Visibilities.setActiveModule("{module}")')
    pump(10)
    assert not ev(nhA, "host.isOpen")
    h.eval(root, f'Config.layout.{module}.host = "notch"')
    pump(10)
    assert ev(nhA, "host.isOpen") and ev(c, "stackView.depth") == 2, module
    assert ev(c, "stackView.currentItem.activeFocus"), module
    assert not ev(nhB, "host.isOpen"), "reroute leaked to other monitor"
    assert ev(vis, f'getForScreen("A").{module}'), "reroute changed visibility"
    count = ev(c, "pushes")
    h.eval(root, 'Config.layout.sheet.side = "left"')
    pump(10)
    assert ev(c, "pushes") == count, "unrelated config duplicated stack view"
    h.eval(root, f'Config.layout.{module}.host = "{outside}"')
    pump(10)
    assert not ev(nhA, "host.isOpen") and ev(c, "stackView.depth") == 1, module
    assert ev(ev(hsA, outside), "isOpen"), "outside host did not reopen"
h.eval(root, 'Config.layout.dashboard.host = "notch"')
pump(10)
# Another path pops the notch stack under an open module: it is put back.
h.eval(root, 'container.stackView.pop()')
pump(20)
assert ev(nhA, "host.isOpen") and ev(c, "stackView.depth") == 2, "routed module lost its view"
# A foreign view on top is never popped by this host's close().
h.eval(root, 'container.stackView.currentItem = Qt.createQmlObject("import QtQuick; Item {}", container); container.stackView.depth = 3')
h.eval(nhA, "host.close()")
assert ev(c, "stackView.depth") == 3, "close() popped a view it does not own"
h.eval(root, 'container.stackView.depth = 1; container.stackView.currentItem = null')
h.eval(root, 'Visibilities.setActiveModule("")')
pump(10)
assert not ev(nhA, "host.isOpen") and ev(c, "stackView.depth") == 1
print("hosts: ok")
h.exit(0)
