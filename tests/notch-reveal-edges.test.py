"""NotchContent reveal on each screen edge (notch.position), offscreen, with
the real Notch and DefaultView, a pinned bar on the left edge and a window
open:
- notch.keepHidden hides the island on every edge, the bar's own included;
  the pointer on its hover strip shows it and leaving hides it again;
- without keepHidden it follows the bar's pin on the bar's edge and hides
  behind the open window on the others."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO  # noqa: E402
from lib import island_stubs  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = island_stubs.island("notch-reveal-edges", """
        property string notchStyle: "attached"
        property var performance: ({ blurTransition: false })
        property var bar: ({ frameEnabled: true, frameThickness: 8, availableOnFullscreen: false, pinnedOnStartup: true })
        property var dock: ({ enabled: false, position: "bottom" })
        function resolveColor(c) { return "white" }
""")
h.module("qs.modules.globals", {"GlobalStates": "pragma Singleton\nQtObject { property bool assistantVisible: false; property int dashboardCurrentTab: 0; property int widgetsTabCurrentIndex: 0 }"})
h.module("qs.modules.theme", {
    "Metrics": "pragma Singleton\nQtObject { property int spacing: 8 }",
    "Motion": "pragma Singleton\nQtObject { property var morph: ({ duration: 0, easing: Easing.OutCubic, overshoot: 1 }); property var enter: morph; property var exit: morph }",
})
h.module("qs.modules.services", {
    "Visibilities": """pragma Singleton
QtObject {
    property bool playerMenuOpen: false
    property var barPanels: ({})
    property var bars: ({})
    function getForScreen(n) { return ({ launcher: false, dashboard: false, powermenu: false, tools: false, aiquick: false, presets: false }) }
}""",
    "ShellLayout": "pragma Singleton\nQtObject { property bool notchEnabled: true; property var notchSegments: [] }",
    "YozdService": "pragma Singleton\nQtObject { property var focusedMonitor: null; property var clients: ({ values: [({ workspace: { id: 1 } })] }); function monitorFor(s) { return ({ activeWorkspace: { id: 1 } }) } }",
    "CompositorData": "pragma Singleton\nQtObject { function monitorHasFullscreen(m) { return false } }",
    "FocusGrabManager": "pragma Singleton\nQtObject { property bool hasActiveGrab: false }",
})
h.module("qs.modules.shell.hosts", {"HostRouter": "pragma Singleton\nQtObject { function notchOpen(v) { return false } }", "NotchHostedSurfaces": "Item { property var screen; property var vis; property var container }"})
h.singleton("qs.modules.shell", "EdgeService", """QtObject {
    property string barEdge: "left"
    function envFor(screen) {
        return { screen: { w: screen.width, h: screen.height }, frame: 8, panels: [{ pos: barEdge, size: 40, visible: true }],
                 dock: { visible: false }, notch: { pos: Config.notchPosition, height: 44, align: "center", visible: true } }
    }
    function notchRect(screen, size) { return EdgeLayout.notchRect(envFor(screen), size) }
}""")
(h.root / "qs/modules/shell/EdgeService.qml").write_text("import QtQuick\nimport qs.config\nimport \"EdgeLayout.js\" as EdgeLayout\n" + (h.root / "qs/modules/shell/EdgeService.qml").read_text())
h.singleton("qs.modules.bar.panels", "Panels", "QtObject { property string primaryEdge: \"left\" }")
h.copy("modules/widgets/defaultview/IslandRail.qml", siblings=False)
import shutil
dvd = h.root / "qs/modules/widgets/defaultview"
dvd.mkdir(parents=True, exist_ok=True)
for f in (h.root / "app").iterdir():
    if f.is_file():
        shutil.copy(f, dvd / f.name)
shutil.copytree(h.root / "app/activities", dvd / "activities", dirs_exist_ok=True)
h._write_qmldir(dvd, "qs.modules.widgets.defaultview")
h.module("qs.modules.corners", {"RoundCorner": "Item { enum CornerEnum { TopLeft, TopRight, BottomLeft, BottomRight } property int corner; property real size; property color color }"})
h.module("Quickshell.Widgets", {"ClippingRectangle": "Rectangle {}"})
h.module("qs.modules.widgets.tools", {"ToolsMenuView": "Item {}"})
h.module("qs.modules.widgets.powermenu", {"PowerMenuView": "Item {}"})
h.module("qs.modules.aicenter.quickask", {"QuickAskCard": "Item {}"})
nd = h.module("qs.modules.notch", {"NotchNotificationView": "Item { property bool notchHovered }"})
notch_dir = REPO / "modules/notch"
for n in ["Notch", "NotchSilhouette", "NotchOutline", "NotchViewTransition", "NotchContent", "NotchPlacement", "NotchHoverHold", "NotchAvoidance"]:
    text = (notch_dir / f"{n}.qml").read_text()
    text = text.replace('import "./NotchNotificationView.qml"\n', "").replace("import Quickshell.Io\n", "").replace("import Quickshell\n", "")
    text = text.replace("required property ShellScreen screen", "required property var screen")
    text = text.replace("id: notchRegionContainer\n", 'id: notchRegionContainer\n        objectName: "nrc"\n')
    (nd / f"{n}.qml").write_text(text)
(nd / "styles").mkdir(exist_ok=True)
(nd / "styles/NotchStyles.js").write_text((notch_dir / "styles/NotchStyles.js").read_text())
for n in ["NotchReveal", "NotchShape", "NotchAvoid"]:
    (nd / f"{n}.js").write_text((notch_dir / f"{n}.js").read_text())
(h.root / "qs/modules/shell/EdgeLayout.js").write_text((REPO / "modules/shell/EdgeLayout.js").read_text())
h._write_qmldir(nd, "qs.modules.notch")

root = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.notch
import qs.config
Window {
    function setPos(p) { Config.notchPosition = p }
    function setKeepHidden(v) { Config.notch = Object.assign({}, Config.notch, { keepHidden: v }) }
    width: 1920; height: 1080; visible: true
    property var screenObj: ({ name: "S", width: 1920, height: 1080 })
    NotchContent { objectName: "nc"; screen: screenObj; anchors.fill: parent }
}""")
QTest.qWaitForWindowExposed(root)
nc = h.find(root, "nc")


def ev(obj, expr):
    v = h.eval(obj, expr)
    return v.toVariant() if hasattr(v, "toVariant") else v


def settle(ms=1300):
    QTest.mouseMove(root, QPoint(960, 540))
    QTest.qWait(ms)


def pixels(sample=4):
    from PySide6.QtGui import QGuiApplication
    img = QGuiApplication.primaryScreen().grabWindow(root.winId()).toImage()
    bg = img.pixelColor(960, 540).rgba()
    return sum(1 for y in range(0, img.height(), sample) for x in range(0, img.width(), sample)
               if img.pixelColor(x, y).alpha() > 0 and img.pixelColor(x, y).rgba() != bg)


EDGES = ["top", "bottom", "left", "right"]

# keepHidden: hidden everywhere (the bar's edge too) until the pointer arrives
h.eval(root, "setKeepHidden(true)")
for pos in EDGES:
    h.eval(root, f"setPos('{pos}')")
    settle()
    assert not h.eval(nc, "reveal"), f"{pos}: keepHidden hides the island"
    assert pixels() == 0, f"{pos}: nothing of the hidden island is drawn"
    sx, sy, sw, sh = ev(nc, "[placement.hoverStrip.x, placement.hoverStrip.y, placement.hoverStrip.w, placement.hoverStrip.h]")
    QTest.mouseMove(root, QPoint(int(sx + sw / 2), int(sy + sh / 2)))
    QTest.qWait(200)
    assert h.eval(nc, "reveal"), f"{pos}: the pointer on the edge strip shows it"
    settle(1500)
    assert not h.eval(nc, "reveal"), f"{pos}: and leaving hides it again"

# no keepHidden: the bar's edge follows the bar's pin, the others hide behind the window
h.eval(root, "setKeepHidden(false)")
for pos in EDGES:
    h.eval(root, f"setPos('{pos}')")
    settle(200)
    assert h.eval(nc, "reveal") == (pos == "left"), f"{pos}: shown only on the bar's edge while a window is open"

print("notch reveal edges: keepHidden on every edge incl. the bar's, hover strip shows, follows the pin otherwise passed")
