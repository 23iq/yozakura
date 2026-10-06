"""HoldToConfirm (modules/components/kit): a press must be held for the whole
ring (at most 600 ms, never instant even with animations off) before
`confirmed` fires; an early release (mouse or Enter) does nothing."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QElapsedTimer, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = KitEnv("hold-to-confirm", overrides={"theme": {"animDuration": 300}})
h = env.h
root = env.load("""import QtQuick
import QtQuick.Window
import qs.modules.components.kit
import qs.modules.theme
Window {
    width: 200; height: 200; visible: true
    property int fired: 0
    HoldToConfirm { objectName: "hold"; width: 64; height: 64; focus: true; onConfirmed: parent.Window.window.fired++ }
}""")
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
