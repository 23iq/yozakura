"""RadialMenu (modules/widgets/menus): opened at the cursor, the whole ring
stays inside the work area at all four corners (EdgeLayout.radialCenter);
keys move the selection, Enter triggers, a confirm item needs a full hold
and Escape dismisses."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.menus_env import MenusEnv  # noqa: E402
from PySide6.QtCore import QElapsedTimer, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = MenusEnv("radial-menu", overrides={"theme": {"animDuration": 0}})
h = env.h
root = env.load("""import QtQuick
import QtQuick.Window
import qs.modules.widgets.menus
Window {
    width: 1920; height: 1080; visible: true
    property int fired: -1
    property int dismissals: 0
    RadialMenu {
        objectName: "menu"
        anchors.fill: parent
        focus: true
        shown: true
        area: ({ x: 40, y: 0, w: 1880, h: 1080 })
        cursor: Qt.point(960, 540)
        items: [
            { icon: "a", label: "Lock" },
            { icon: "b", label: "Suspend" },
            { icon: "c", label: "Power off", hold: "Hold to shut down", confirm: true }
        ]
        onTriggered: index => parent.Window.window.fired = index
        onDismissed: parent.Window.window.dismissals++
    }
}""")
root.requestActivate()
menu = h.find(root, "menu")


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


r = menu.property("outerRadius")
assert r > 0
for name, (x, y) in {"top-left": (0, 0), "top-right": (1919, 0), "bottom-left": (0, 1079),
                     "bottom-right": (1919, 1079), "middle": (960, 540)}.items():
    h.eval(menu, f"cursor = Qt.point({x}, {y})")
    cx, cy = h.eval(menu, "center.x"), h.eval(menu, "center.y")
    assert 40 + r <= cx <= 1920 - r and r <= cy <= 1080 - r, (name, cx, cy, r)
    for i in range(3):
        it = h.eval(menu, f"itemAt({i})")
        p = h.eval(it, "mapToItem(null, 0, 0)")
        w, hh = it.property("width"), it.property("height")
        assert p.x() >= 40 and p.y() >= 0 and p.x() + w <= 1920 and p.y() + hh <= 1080, (name, i, p)
    if name == "middle":
        assert (cx, cy) == (960, 540), "unclamped at the center"

pump(20)
assert h.eval(menu, "currentIndex") == 0
QTest.keyClick(root, Qt.Key_Right)
assert h.eval(menu, "currentIndex") == 1
QTest.keyClick(root, Qt.Key_Return)
pump(20)
assert root.property("fired") == 1

# confirm item: an Enter tap does nothing, a full hold triggers
root.setProperty("fired", -1)
QTest.keyClick(root, Qt.Key_Right)
assert h.eval(menu, "currentIndex") == 2
QTest.keyPress(root, Qt.Key_Return)
pump(120)
QTest.keyRelease(root, Qt.Key_Return)
pump(700)
assert root.property("fired") == -1, "a tap on a confirm item must not trigger"
QTest.keyPress(root, Qt.Key_Return)
pump(750)
QTest.keyRelease(root, Qt.Key_Return)
pump(20)
assert root.property("fired") == 2, root.property("fired")

# the center names the selection and asks to hold a confirm item
assert h.eval(h.find(root, "radialLabel"), "text") == "Power off"
assert h.eval(h.find(root, "radialHint"), "text") == "Hold to shut down"
QTest.keyClick(root, Qt.Key_Left)
assert h.eval(h.find(root, "radialHint"), "visible") is False

QTest.keyClick(root, Qt.Key_Escape)
assert root.property("dismissals") == 1

print("radial-menu: ok")
h.exit(0)
