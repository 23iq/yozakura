"""HoldToConfirm (modules/components): a press must be held for the whole
ring (at most 600 ms, never instant even with animations off) before
`confirmed` fires; an early release (mouse or Enter) does nothing."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QElapsedTimer, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("hold-to-confirm")
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 300 }")
h.module("qs.modules.theme", {
    "Motion": """pragma Singleton
QtObject {
    property QtObject emphasis: QtObject { property int duration: 450; property int easing: Easing.OutCubic; property real overshoot: 1 }
}""",
    "Colors": "pragma Singleton\nQtObject { property color primary: 'red'; property color outline: 'gray' }",
})
h.copy("modules/components/HoldToConfirm.qml", "qs/modules/components")
h.module("qs.modules.components", {})

root = h.load("""import QtQuick
import QtQuick.Window
import qs.modules.components
import qs.modules.theme
Window {
    width: 200; height: 200; visible: true
    property int fired: 0
    HoldToConfirm { objectName: "hold"; width: 64; height: 64; focus: true; onConfirmed: parent.Window.window.fired++ }
}""", auto_stub=False)
root.requestActivate()
hold = h.find(root, "hold")


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


ms = hold.property("holdMs")
assert 400 <= ms <= 600, ms

# early release: nothing happens, the ring winds back
h.eval(hold, "press()")
assert hold.property("holding")
pump(ms // 3)
h.eval(hold, "release()")
pump(ms + 150)
assert root.property("fired") == 0, "early release must not confirm"
assert not hold.property("holding")
assert hold.property("progress") == 0

# a full hold confirms exactly once
h.eval(hold, "press()")
pump(ms + 150)
h.eval(hold, "release()")
pump(50)
assert root.property("fired") == 1, root.property("fired")

# keyboard: holding Enter confirms, a tap does not
h.eval(hold, "forceActiveFocus()")
pump(20)
QTest.keyPress(root, Qt.Key_Return)
pump(ms // 4)
QTest.keyRelease(root, Qt.Key_Return)
pump(ms + 150)
assert root.property("fired") == 1, "an Enter tap must not confirm"
QTest.keyPress(root, Qt.Key_Return)
pump(ms + 150)
QTest.keyRelease(root, Qt.Key_Return)
pump(30)
assert root.property("fired") == 2, root.property("fired")

# animations off: still a real hold, never instant
h.eval(root, "Motion.emphasis.duration = 0")
ms0 = hold.property("holdMs")
assert ms0 >= 400, ms0
h.eval(hold, "press()")
pump(60)
h.eval(hold, "release()")
pump(20)
assert root.property("fired") == 2

print("hold-to-confirm: ok")
h.exit(0)
