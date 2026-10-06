"""RadialMenu (modules/components): opened at the cursor, the whole ring
stays inside the work area at all four corners (EdgeLayout.radialCenter);
keys move the selection, Enter triggers, a confirm item needs a full hold
and Escape dismisses."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QElapsedTimer, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("radial-menu")
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 0; property string defaultFont: 'sans' }")
h.module("qs.modules.theme", {
    "Motion": """pragma Singleton
QtObject {
    property QtObject enter: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject exit: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject emphasis: QtObject { property int duration: 450; property int easing: Easing.OutCubic; property real overshoot: 1 }
}""",
    "Metrics": "pragma Singleton\nQtObject { property int rowHeight: 48; property int iconSize: 32; property int spacing: 8; property int padding: 16 }",
    "Colors": "pragma Singleton\nQtObject { property color primary: 'red'; property color overBackground: 'white'; property color error: 'red' }",
    "Icons": "pragma Singleton\nQtObject { property string font: 'sans' }",
    "Styling": "pragma Singleton\nQtObject { function fontSize(o) { return 14 + o; } function radius(o) { return 16 + o; } function srItem(v) { return 'white'; } }",
})
h.copy("modules/components/HoldToConfirm.qml", "qs/modules/components")
h.copy("modules/components/RadialMenu.qml", "qs/modules/components")
h.copy("modules/shell/EdgeLayout.js", "qs/modules/shell")
h.module("qs.modules.components", {"StyledRect": "Item { property string variant; property real radius; property bool enableShadow }"})

root = h.load("""import QtQuick
import QtQuick.Window
import qs.modules.components
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
            { icon: "c", label: "Power off", confirm: true }
        ]
        onTriggered: index => parent.Window.window.fired = index
        onDismissed: parent.Window.window.dismissals++
    }
}""", auto_stub=False)
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

QTest.keyClick(root, Qt.Key_Escape)
assert root.property("dismissals") == 1

print("radial-menu: ok")
h.exit(0)
