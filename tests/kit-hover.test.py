"""Kit hover and placement: a ListRow stays hovered while the pointer is over
one of its trailing controls (a HoverHandler, not a MouseArea the controls
cover), a Dropdown near the bottom of its window opens its list above
the control instead of off-screen, and an IconButton's tooltip (the kit
Tooltip) opens below the button, or above it at the bottom of the window
(a dock), inside the window either way. Its accessible name is
`accessibleName`, else the tooltip."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QObject, QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from waits import wait_until  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 400; height: 300; visible: true
    ListRow { objectName: "row"; width: 300; title: "Mira"
              trailing: Component { IconButton { objectName: "trail"; icon: Icons.gear } } }
    Dropdown { objectName: "low"; y: 260; width: 200; value: "a"
               options: [{ value: "a", text: "Alpha" }, { value: "b", text: "Beta" }, { value: "c", text: "Gamma" }] }
    Dropdown { objectName: "high"; y: 60; width: 200; value: "a"
               options: [{ value: "a", text: "Alpha" }, { value: "b", text: "Beta" }] }
    IconButton { objectName: "tipTop"; x: 300; y: 100; icon: Icons.gear; tooltip: "Settings" }
    IconButton { objectName: "tipLow"; x: 300; y: 300 - height; icon: Icons.gear; tooltip: "Pin to dock" }
    IconButton { objectName: "named"; x: 0; y: 200; icon: Icons.gear; tooltip: "Tip"; accessibleName: "Open settings" }
}"""

env = KitEnv("kit-hover")
h = env.h
win = env.load(SCENE)
row = h.find(win, "row")
trail = h.find(win, "trail")


def move(x, y):
    QTest.mouseMove(win, QPoint(int(x), int(y)))
    QTest.qWait(20)


move(20, row.property("height") / 2)
assert row.property("hovered"), "pointer on the row hovers it"
tp = h.eval(trail, "mapToItem(null, width / 2, height / 2)")
move(tp.x(), tp.y())
assert trail.property("hovered"), "the trailing control is hovered"
assert row.property("hovered"), "the row stays hovered over its trailing control"
move(390, 150)
assert not row.property("hovered"), "leaving the row clears the hover"

for name, above in (("low", True), ("high", False)):
    dd = h.find(win, name)
    lst = h.find(dd, "dropdownList")
    lst.open()
    QTest.qWait(20)
    y = lst.property("y")
    assert (y < 0) == above, (name, y)
    lst.close()
    QTest.qWait(20)

for name, below in (("tipTop", True), ("tipLow", False)):
    btn = h.find(win, name)
    c = h.eval(btn, "mapToItem(null, width / 2, height / 2)")
    move(c.x(), c.y())
    tip = btn.findChild(QObject, "iconButtonTooltip")
    assert tip is not None, f"{name}: IconButton carries the kit Tooltip"
    wait_until(lambda t=tip: t.property("opened"))
    assert tip.property("text") == btn.property("tooltip"), name
    top = tip.property("y") + h.eval(btn, "mapToItem(null, 0, 0)").y()
    by = h.eval(btn, "mapToItem(null, 0, 0)").y()
    tip_h = tip.property("height")
    if below:
        assert top >= by + btn.property("height"), (name, "below the button", top, by)
    else:
        assert top + tip_h <= by + 1, (name, "above the button", top, tip_h, by)
    assert top >= 0 and top + tip_h <= 300 + 1, (name, "inside the window", top, tip_h)
    move(10, 10)
    wait_until(lambda t=tip: not t.property("visible"))


# the accessible name: accessibleName first, else the tooltip
assert h.eval(h.find(win, "named"), "Accessible.name") == "Open settings"
assert h.eval(h.find(win, "tipTop"), "Accessible.name") == "Settings"
assert h.eval(trail, "Accessible.name") == ""

print("kit-hover: ok")
