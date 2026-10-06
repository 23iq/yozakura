"""Dock indicator styles (modules/dock/DockIndicator.qml + indicators/*):
each dock.indicator style loads, draws at most three marks and hugs the
screen edge of a dock on any of the four edges; unknown styles fall back to
the dot.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
h = Harness("dock-indicator")
h.singleton("qs.config", "Config", 'QtObject { property QtObject dock: QtObject { property string indicator: "dot" }\n'
            "property int animDuration: 0 }")
h.singleton("qs.modules.theme", "Styling", 'QtObject { function srItem(n) { return "#ff0000" } }')
h.singleton("qs.modules.theme", "Colors", 'QtObject { property color overBackground: "#ffffff" }')
h.copy("modules/dock/DockIndicator.qml")
for f in sorted((ROOT / "modules/dock/indicators").glob("*.qml")):
    h.copy(f.relative_to(ROOT))

root = h.load("""
import QtQuick
import qs.config
Item {
    width: 60; height: 60
    function setStyle(s) { Config.dock.indicator = s }
    DockIndicator { id: di; objectName: "di"; edge: "bottom"; count: 2; active: true }
}
""")
win = QQuickWindow()
win.resize(60, 60)
root.setParentItem(win.contentItem())
win.show()
di = h.find(root, "di")


def strip():
    QTest.qWait(120)
    """[x, y, w, h] of the mark grid inside the 60x60 cell."""
    return json.loads(h.eval(di, "(function () { var s = item.children[0]; return JSON.stringify([s.x, s.y, s.width, s.height]); })()"))


FAILED = []


def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        FAILED.append(msg)


for style in ("dot", "line", "glow", "brush", "bogus"):
    h.eval(root, f'setStyle("{style}")')
    for count, n in ((1, 1), (3, 3), (5, 3)):
        di.setProperty("count", count)
        check(h.eval(di, "item !== null && item.info.n") == n, f"{style}: {count} windows draw {n} marks")
    di.setProperty("count", 2)
    for edge in ("bottom", "top", "left", "right"):
        di.setProperty("edge", edge)
        x, y, w, hh = strip()
        check(w > 0 and hh > 0, f"{style}/{edge}: strip has a size {(x, y, w, hh)}")
        if edge == "bottom":
            check(y > 30 and abs(x + w / 2 - 30) < 1, f"{style}/bottom: below, centered ({x},{y},{w},{hh})")
        elif edge == "top":
            check(y < 30 and abs(x + w / 2 - 30) < 1, f"{style}/top: above, centered ({x},{y},{w},{hh})")
        elif edge == "left":
            check(x < 30 and abs(y + hh / 2 - 30) < 1 and hh >= w, f"{style}/left: left side, stacked ({x},{y},{w},{hh})")
        else:
            check(x > 30 and abs(y + hh / 2 - 30) < 1 and hh >= w, f"{style}/right: right side, stacked ({x},{y},{w},{hh})")

h.eval(root, 'setStyle("line")')
check("LineIndicator" in str(h.eval(di, "String(item)")), "line style loads LineIndicator")
sys.exit(1 if FAILED else 0)
