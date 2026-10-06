"""The island on each of the four screen edges (notch.position) x notch.align
x a bar on each edge, offscreen, with the real Notch, DefaultView and
NotchPlacement (EdgeLayout): with a panel open it stays on screen, off the
bar and opens toward the screen center; on a side edge it stands upright
(header stacked along the edge) and its panel opens beside the header."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO  # noqa: E402
from lib import island_stubs  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = island_stubs.island("island-edges", """
        property string notchStyle: "island"
        property var performance: ({ blurTransition: false })
        function resolveColor(c) { return "white" }
""")
h.module("qs.modules.globals", {})
h.module("qs.modules.theme", {
    "Metrics": "pragma Singleton\nQtObject { property int spacing: 8 }",
    "Motion": "pragma Singleton\nQtObject { property var morph: ({ duration: 0, easing: Easing.OutCubic, overshoot: 1 }); property var enter: morph; property var exit: morph }",
})
h.module("qs.modules.corners", {"RoundCorner": "Item { enum CornerEnum { TopLeft, TopRight, BottomLeft, BottomRight } property int corner; property real size; property color color }"})
h.singleton("qs.modules.shell.hosts", "HostRouter", "QtObject { function notchOpen(v) { return false } }")
h.module("Quickshell.Widgets", {"ClippingRectangle": "Rectangle {}"})
notch_dir = REPO / "modules/notch"
nd = h.module("qs.modules.notch", {n: (notch_dir / f"{n}.qml").read_text() for n in ["Notch", "NotchSilhouette", "NotchOutline", "NotchViewTransition", "NotchPlacement"]})
(nd / "NotchShape.js").write_text((notch_dir / "NotchShape.js").read_text())
(nd / "styles").mkdir(exist_ok=True)
(nd / "styles/NotchStyles.js").write_text((notch_dir / "styles/NotchStyles.js").read_text())
(h.root / "qs/modules/shell").mkdir(parents=True, exist_ok=True)
(h.root / "qs/modules/shell/EdgeLayout.js").write_text((REPO / "modules/shell/EdgeLayout.js").read_text())
h.copy("modules/widgets/defaultview/IslandRail.qml", siblings=False)
(h.root / "app/EdgesRoot.qml").write_text("""import QtQuick
import QtQuick.Controls
import qs.config
import qs.modules.notch
import qs.modules.services.activities
Item {
    id: root
    width: 1920; height: 1080
    property var env: null
    Component { id: dv; DefaultView { objectName: "view"; screenName: "S" } }
    Notch { id: notch; objectName: "notch"; defaultViewComponent: dv; screenName: "S"; visibilities: ({}) }
    NotchPlacement { id: place; env: root.env; width: notch.implicitWidth; height: notch.implicitHeight }
    readonly property var view: notch.defaultView
    readonly property var rect: place.rect
    ScrollIndicator {}
}
""")
root = h.load(h.root / "app/EdgesRoot.qml")
QTest.qWait(10)
assert h.eval(root, "view !== null"), "the resting view is created"
view = h.find(root, "view")
header = h.find(root, "islandHeader")

EDGES = ["top", "bottom", "left", "right"]
ALIGNS = ["start", "center", "end"]
BAR = 40
SCREEN = (1920, 1080)


def ev(obj, expr):
    v = h.eval(obj, expr)
    return v.toVariant() if hasattr(v, "toVariant") else v


def bar_rect(edge):
    w, hh = SCREEN
    return {"top": (0, 0, w, BAR), "bottom": (0, hh - BAR, w, BAR), "left": (0, 0, BAR, hh), "right": (w - BAR, 0, BAR, hh)}[edge]


def overlaps(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def place(edge, align, bar):
    h.eval(root, f"env = ({{ screen: {{ w: {SCREEN[0]}, h: {SCREEN[1]} }}, frame: 0, bar: {{ pos: '{bar}', size: {BAR}, visible: true }}, dock: {{ pos: 'bottom', size: 0, visible: false }}, notch: {{ pos: '{edge}', height: 36, align: '{align}', visible: true }} }})")
    QTest.qWait(1)
    r = ev(root, "[rect.x, rect.y, rect.w, rect.h, rect.dir]")
    return tuple(r[:4]), r[4]


act = "({ id: 'downloads', source: 'downloads', category: 'task', priority: 40, indicator: 'ring', label: '47%', icon: '', image: '', detail: 'd', progress: 0.5, color: 'primary' })"
h.eval(root, "ActivityService.transfers = [({ id: 'b:1', source: 'browserDownloads', title: 'a.iso', processed: 1, total: 2, rate: 1, state: 'running', units: 'bytes', actions: [] })]")
h.eval(root, f"ActivityService.activities = [{act}]")
QTest.qWait(5)

for edge in EDGES:
    vertical = edge in ("left", "right")
    h.eval(root, f"Config.notchPosition = '{edge}'")
    h.eval(header, "tasksSegment.hoverOverride = false")
    QTest.qWait(40)
    # resting: a strip along its edge, the header re-laid (not rotated)
    w, hh = ev(root, "[notch.implicitWidth, notch.implicitHeight]")
    assert (hh > w) if vertical else (w > hh), f"{edge}: the resting island lies along its edge ({w}x{hh})"
    assert h.eval(header, "vertical") == vertical, edge
    assert h.eval(header, "rotation") == 0 and h.eval(root, "notch.rotation") == 0, f"{edge}: nothing is rotated"
    if vertical:
        assert h.eval(header, "width") == h.eval(header, "thickness"), f"{edge}: the header is one island thick"
        assert h.eval(header, "tasksSegment.height") > 0, f"{edge}: the segment stacks in the header"

    # open the downloads panel
    h.eval(header, "tasksSegment.hoverOverride = true")
    QTest.qWait(60)
    assert h.eval(view, "panelExpanded"), f"{edge}: the panel opens"
    w2, h2 = ev(root, "[notch.implicitWidth, notch.implicitHeight]")
    assert w2 >= 440 and h2 > h.eval(header, "implicitHeight" if not vertical else "36"), f"{edge}: the island grows to the panel ({w2}x{h2})"
    if vertical:
        # the panel sits beside the header, toward the screen center
        body = h.find(root, "islandBody")
        hx, hw = ev(header, "[x, width]")
        bx, bw = ev(body, "[x, width]")
        assert bw >= 440, f"{edge}: the panel area takes the panel width"
        assert (bx >= hx + hw) if edge == "left" else (bx + bw <= hx), f"{edge}: panel beside the header ({hx},{hw} / {bx},{bw})"

    for align in ALIGNS:
        for bar in EDGES:
            r, d = place(edge, align, bar)
            tag = f"{edge}/{align}/bar {bar}"
            assert r[2] == w2 and r[3] == h2, tag
            assert r[0] >= 0 and r[1] >= 0 and r[0] + r[2] <= SCREEN[0] and r[1] + r[3] <= SCREEN[1], f"{tag}: on screen {r}"
            assert d == {"top": "down", "bottom": "up", "left": "right", "right": "left"}[edge], tag
            # a top/bottom bar keeps a gap for a notch on its edge; anything
            # else must stay clear of the bar
            if not (bar == edge and not vertical):
                assert not overlaps(r, bar_rect(bar)), f"{tag}: off the bar {r}"
            if vertical and bar == edge:
                assert (r[0] == BAR) if edge == "left" else (r[0] + r[2] == SCREEN[0] - BAR), f"{tag}: beside the bar"

print("island edges: 4 edges x align x bar, upright side island, panels toward the center, on screen and off the bar passed")
