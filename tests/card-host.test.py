"""Card host (modules/shell/hosts/CardHost.qml) with its owners, offscreen:
PanelSurfaces shows the notch's auto panels (timers hub, voice, alarm) in a
floating card when layout.panels.host resolves off the notch, beside the bar
on every edge and never under it; Escape and a click outside dismiss a
modal panel through its own dismissed() (TimersService.closeHub); the alarm
card is not modal; the notch host keeps them. HostedSurfaces shows the AI
quick ask in the card or the spotlight (layout.aiquick.host)."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QElapsedTimer, QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
h = Harness("card-host")

h.module("Quickshell", {
    "Scope": "Item {}",
    "Singleton": "QtObject {}",
    "ShellScreen": "QtObject { property string name; property int width; property int height }",
    "Region": "QtObject { property Item item }",
})
h.singleton("Quickshell", "Quickshell", 'QtObject { property var screens: [] }')
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject layout: QtObject {
        property QtObject launcher: QtObject { property string host: "spotlight" }
        property QtObject dashboard: QtObject { property string host: "sheet" }
        property QtObject sheet: QtObject { property string side: "auto" }
        property QtObject cheatsheet: QtObject { property string host: "fullscreen" }
        property QtObject aiquick: QtObject { property string host: "auto" }
        property QtObject panels: QtObject { property string host: "auto" }
        property bool backdrop: false
    }
    property QtObject bar: QtObject { property string position: "top"; property bool frameEnabled: false }
    property QtObject dock: QtObject { property string position: "bottom"; property int height: 64; property bool enabled: false }
    property QtObject notch: QtObject { property string position: "top"; property bool enabled: false; property int expandedMediaWidth: 440 }
    property QtObject system: QtObject { property QtObject timers: QtObject { property bool alarmPanel: true; property int alarmRepeat: 3 } }
}""")
h.module("qs.modules.globals", {})
MOTION = """pragma Singleton
import qs.config
QtObject {
    property int d: Config.animDuration
    property QtObject enter: QtObject { property int duration: Motion.d; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject exit: QtObject { property int duration: Motion.d; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject glide: QtObject { property int duration: Math.round(Motion.d * 0.8); property int easing: Easing.OutCubic; property real overshoot: 1 }
}"""
h.module("qs.modules.theme", {
    "Motion": MOTION,
    "Metrics": "pragma Singleton\nQtObject { property int padding: 16; property int sheetW: 420 }",
    "BarMetrics": "pragma Singleton\nimport qs.config\nQtObject { property int moduleSize: 40; property int notchRestHeight: 36 }",
    "Colors": "pragma Singleton\nQtObject { property color scrim: '#000000' }",
    "Styling": "pragma Singleton\nQtObject { function radius(o) { return 16 + o; } }",
})
h.module("qs.modules.components", {"StyledRect": "Item { property string variant; property real radius; property bool enableShadow }"})
h.module("qs.modules.components.kit", {
    "Space": "pragma Singleton\nQtObject { property int s: 8; property int m: 12; property int l: 16 }",
    "Surface": "Item { property int padding; property bool floating; default property alias content: body.data\n"
               "    Item { id: body; anchors.fill: parent } }",
})
h.module("qs.modules.services", {"FocusGrab": "QtObject { property var windows; property bool active; signal cleared }"})
h.singleton("qs.modules.services", "ShellLayout", """QtObject {
    property bool notchEnabled: false
    property bool barEnabled: true
    property var layout: ({bar: {edges: ["top"], edge: "top"}})
}""")
h.singleton("qs.modules.services", "TimersService", """QtObject {
    property bool hubOpen: false; property string hubScreen: ""
    property int ringing: 0; property string alarmScreen: ""
    function closeHub() { hubOpen = false }
}""")
h.singleton("qs.modules.services", "VoiceService", 'QtObject { property bool panelOpen: false; property string panelScreen: "" }')
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
        for (const k in screens) { screens[k].launcher = false; screens[k].dashboard = false; screens[k].aiquick = false; }
        if (m) getForScreen(focused)[m] = true;
    }
}""")
VIEW = "Item { objectName: 'view'; focus: true; implicitWidth: 464; implicitHeight: 296; property string screenName }"
h.module("qs.modules.widgets.launcher", {"LauncherView": VIEW})
h.module("qs.modules.widgets.dashboard", {"DashboardView": VIEW})
h.module("qs.modules.keybinds", {"CheatsheetView": VIEW})
h.module("qs.modules.aicenter.quickask", {"QuickAskCard": VIEW.replace("'view'", "'quickask'").replace("464", "560").replace("296", "120")})
for f in ("Motion", "Metrics", "BarMetrics"):
    p = h.root / "qs/modules/theme" / f"{f}.qml"
    if "import qs.config" not in p.read_text():
        p.write_text("import qs.config\n" + p.read_text())

h.copy("modules/shell/EdgeService.qml", "qs/modules/shell")
h.module("qs.modules.shell", {})
HOSTS = "qs/modules/shell/hosts"
src = (REPO / "modules/shell/hosts/SurfaceHost.qml").read_text()
item = src.replace("import Quickshell.Wayland\n", "").replace("PanelWindow {", "Item {\n    property var screen\n    property var mask\n    width: 1920\n    height: 1080", 1)
item = re.sub(r"\n    anchors \{[^}]*\}", "", item, count=1)
item = "\n".join(ln for ln in item.split("\n") if not re.match(r'\s*(color: "transparent"|exclusionMode:|WlrLayershell\.)', ln))
h.copy("modules/shell/hosts/SurfaceHost.qml", HOSTS, replace={src: item})
for f in ("HostBackdrop", "HostFrame", "CardHost", "SpotlightHost", "SheetHost", "HostRouter", "HostedSurfaces", "PanelSurfaces"):
    h.copy(f"modules/shell/hosts/{f}.qml", HOSTS)
h.module("qs.modules.shell.hosts", {})
# After the copies (NotchPanels.js pulls in the real panels)
# The notch panels: NotchPanel's API, sized like the real ones
PANEL = ("import qs.modules.services\nNotchPanel {{ objectName: '{name}'; implicitHeight: {h}; property int dismissals: 0\n"
         "    focus: true; onDismissed: {{ dismissals++; {on} }} }}")
h.module("qs.modules.widgets.defaultview.panels", {
    "NotchPanel": "Item { property string screenName; property bool revealed; property int maxRows; signal closeRequested; signal dismissed }",
    "TimerHubPanel": PANEL.format(name="timerHub", h=240, on="TimersService.closeHub()"),
    "VoicePanel": PANEL.format(name="voice", h=160, on="VoiceService.panelOpen = false"),
    "AlarmPanel": PANEL.format(name="alarm", h=120, on=""),
})

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
    PanelSurfaces { objectName: "psA"; screen: a }
    PanelSurfaces { objectName: "psB"; screen: b }
    HostedSurfaces { objectName: "hsA"; screen: a }
}""", auto_stub=False)
root.requestActivate()
psA, psB, hsA = h.find(root, "psA"), h.find(root, "psB"), h.find(root, "hsA")


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


def ev(obj, expr):
    return h.eval(obj, expr)


def rect(host):
    f = h.find(host, "cardFrame")
    p = h.eval(f, "mapToItem(null, 0, 0)")
    return {"x": p.x(), "y": p.y(), "w": f.property("width"), "h": f.property("height")}


def overlaps(a, b):
    return a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]


BAR = {"top": {"x": 0, "y": 0, "w": 1920, "h": 40}, "bottom": {"x": 0, "y": 1040, "w": 1920, "h": 40},
       "left": {"x": 0, "y": 0, "w": 40, "h": 1080}, "right": {"x": 1880, "y": 0, "w": 40, "h": 1080}}

# The timers hub off a disabled notch: a card on screen A only, beside the
# bar on every edge, focused, sized from the panel (registry width 460)
for edge in ("top", "bottom", "left", "right"):
    h.eval(root, f'Config.bar.position = "{edge}"')
    h.eval(root, 'TimersService.hubScreen = "A"; TimersService.hubOpen = true')
    pump(20)
    card = ev(psA, "card")
    assert card is not None and ev(card, "isOpen") and ev(card, "progress") == 1, edge
    assert ev(card, "view.objectName") == "timerHub" and ev(card, "modal"), edge
    assert ev(psB, "card") is None or not ev(ev(psB, "card"), "isOpen"), f"{edge}: other screen"
    pump(10)
    assert ev(card, "view.activeFocus"), f"{edge}: focus"
    r = rect(card)
    assert r["w"] == 460 and r["h"] == 240, f"{edge}: {r}"
    assert not overlaps(r, BAR[edge]), f"{edge}: under the bar {r}"
    assert r["x"] >= 0 and r["y"] >= 0 and r["x"] + r["w"] <= 1920 and r["y"] + r["h"] <= 1080, edge
    assert ev(card, "area.corner").split("-").count(edge) == 1, f"{edge}: {ev(card, 'area.corner')}"
    # Escape -> the panel's dismissed() -> TimersService.closeHub()
    QTest.keyClick(root, Qt.Key_Escape)
    pump(20)
    assert not ev(card, "isOpen") and not ev(card, "visible"), f"{edge}: escape"
    assert not ev(root, "TimersService.hubOpen"), f"{edge}: hub not closed"
    assert ev(psA, "shownId") == "", f"{edge}: panel kept after closing"

# Click outside dismisses; a click on the card does not
h.eval(root, 'Config.bar.position = "top"; TimersService.hubOpen = true')
pump(20)
card = ev(psA, "card")
r = rect(card)
QTest.mouseClick(root, Qt.LeftButton, Qt.NoModifier, QPoint(int(r["x"] + 20), int(r["y"] + 20)))
pump(10)
assert ev(card, "isOpen"), "click on the card closed it"
QTest.mouseClick(root, Qt.LeftButton, Qt.NoModifier, QPoint(300, 700))
pump(20)
assert not ev(card, "isOpen") and not ev(root, "TimersService.hubOpen"), "click outside kept it"

# Voice comes first (registry order); the ringing alarm is not modal and
# stays dismissed until it stops ringing
h.eval(root, 'VoiceService.panelOpen = true; TimersService.ringing = 1')
pump(20)
assert ev(card, "isOpen") and ev(card, "view.objectName") == "voice" and ev(card, "modal")
h.eval(root, "VoiceService.panelOpen = false")
pump(20)
assert ev(card, "isOpen") and ev(card, "view.objectName") == "alarm", "alarm after voice"
assert not ev(card, "modal"), "alarm card is modal"
h.eval(psA, "dismiss()")
pump(20)
assert not ev(card, "isOpen") and ev(psA, "dismissedId") == "alarm"
h.eval(root, "TimersService.ringing = 0")
pump(10)
assert ev(psA, "dismissedId") == "", "dismissal outlived the alarm"
h.eval(root, "TimersService.ringing = 1")
pump(20)
assert ev(card, "isOpen"), "a new alarm stayed hidden"
h.eval(root, "TimersService.ringing = 0")
pump(20)
assert not ev(card, "isOpen")

# The notch on (auto) hosts the panels: no card; an explicit card keeps it
h.eval(root, "ShellLayout.notchEnabled = true; TimersService.hubOpen = true")
pump(20)
assert not ev(card, "isOpen") and not ev(psA, "active"), "card while the notch hosts the panels"
h.eval(root, 'Config.layout.panels.host = "card"')
pump(20)
assert ev(card, "isOpen"), "explicit card with the notch on"
h.eval(root, 'TimersService.hubOpen = false; Config.layout.panels.host = "auto"; ShellLayout.notchEnabled = false')
pump(20)

# Glides: opens and closes with Motion.glide, nothing stuck half-way
h.eval(root, "Config.animDuration = 200; TimersService.hubOpen = true")
pump(5)
assert ev(card, "progress") < 1
pump(400)
assert ev(card, "progress") == 1
h.eval(root, "TimersService.hubOpen = false")
pump(400)
assert ev(card, "progress") == 0 and not ev(card, "visible") and ev(psA, "shownId") == ""
h.eval(root, "Config.animDuration = 0")

# AI quick ask: a card off the notch (auto), the spotlight when chosen
h.eval(root, 'Visibilities.setActiveModule("aiquick")')
pump(20)
qa = ev(hsA, "card")
assert qa is not None and ev(qa, "isOpen") and ev(qa, "view.objectName") == "quickask", "quick ask card"
r = rect(qa)
assert r["w"] == 560 + 2 * 12 and not overlaps(r, BAR["top"]), r
QTest.keyClick(root, Qt.Key_Escape)
pump(20)
assert not ev(qa, "isOpen") and not ev(root, 'Visibilities.getForScreen("A").aiquick'), "quick ask escape"
h.eval(root, 'Config.layout.aiquick.host = "spotlight"; Visibilities.setActiveModule("aiquick")')
pump(20)
assert ev(ev(hsA, "spotlight"), "isOpen") and not ev(qa, "isOpen"), "quick ask in the spotlight"
h.eval(root, 'Visibilities.setActiveModule("")')
pump(20)
# The notch on: auto quick ask is the notch's again
h.eval(root, 'Config.layout.aiquick.host = "auto"; ShellLayout.notchEnabled = true; Visibilities.setActiveModule("aiquick")')
pump(20)
assert not ev(qa, "isOpen") and not ev(ev(hsA, "spotlight"), "isOpen"), "quick ask left the notch"
print("card host: ok")
h.exit(0)
