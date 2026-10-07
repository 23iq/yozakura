"""Kit hover and placement: a ListRow stays hovered while the pointer is over
one of its trailing controls (a HoverHandler, not a MouseArea the controls
cover), and a Dropdown near the bottom of its window opens its list above
the control instead of off-screen."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

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

print("kit-hover: ok")
