"""SurfaceLatch and SettleGate: the native-crash guards for layer windows.

SurfaceLatch: a closing panel releases focus, then drops keyboard focus,
then unmaps at least one frame later (never in the same tick); reopening
in between keeps it mapped. SettleGate: a bursty value is let through only
after it held still, so windows are not recreated per burst step.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness("surface-latch")
h.copy("modules/components/SurfaceLatch.qml")
h.copy("modules/components/SettleGate.qml")
root = h.load('''import QtQuick
Window {
    id: top
    visible: true
    width: 200
    height: 100
    property alias field: field
    TextInput { id: field; width: 100; height: 20; text: "draft" }
    property alias latch: latch
    property alias gate: gate
    property alias burst: burst
    property var log: []
    property bool open: false
    property int holdMs: 0
    SurfaceLatch {
        id: latch
        active: top.open
        holdMs: top.holdMs
        focusHost: field
        onReleaseFocus: top.log = top.log.concat(["release:" + keyboard + ":" + field.activeFocus])
        onKeyboardChanged: top.log = top.log.concat(["keyboard:" + keyboard])
        onShownChanged: top.log = top.log.concat(["shown:" + shown])
    }
    property bool flag: false
    SettleGate { id: gate; value: top.flag; interval: 120 }
    property var screens: ["a"]
    SettleGate { id: burst; value: top.screens; interval: 120; startSettled: false }
}''', auto_stub=False)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


ev = h.eval

# Created mid-burst: nothing let through yet.
assert ev(root, "burst.settled") is False

# Closed at start: nothing mapped.
assert ev(root, "latch.shown") is False and ev(root, "latch.keyboard") is False

ev(root, "open = true")
assert ev(root, "latch.shown") is True and ev(root, "latch.keyboard") is True
ev(root, "requestActivate(); field.forceActiveFocus()")
pump(20)
assert ev(root, "field.activeFocus") is True

# Close with 0 ms animations: the text field loses focus before the
# keyboard drops, and
# the surface stays mapped in this tick.
ev(root, "log = []; open = false")
assert ev(root, "log.join()") == "release:true:false,keyboard:false", ev(root, "log.join()")
assert ev(root, "latch.shown") is True, "unmap must not share the tick with the focus drop"
pump(5)
assert ev(root, "latch.shown") is True, "unmap waits at least one frame"
pump(60)
assert ev(root, "latch.shown") is False
assert ev(root, "log.join()") == "release:true:false,keyboard:false,shown:false", ev(root, "log.join()")

# Close then reopen inside the hold: never unmapped.
ev(root, "holdMs = 80; open = true; log = []")
ev(root, "open = false")
pump(30)
ev(root, "open = true")
pump(150)
assert ev(root, "latch.shown") is True and ev(root, "latch.keyboard") is True
assert "shown:false" not in ev(root, "log.join()"), ev(root, "log.join()")

# The hold follows the animation length.
ev(root, "open = false")
pump(50)
assert ev(root, "latch.shown") is True, "still sliding out"
pump(120)
assert ev(root, "latch.shown") is False

# SettleGate: initial value passes at once; a burst lands once, at the end.
assert ev(root, "gate.output") is False and ev(root, "gate.settled") is True
ev(root, "flag = true")
assert ev(root, "gate.settled") is False and ev(root, "gate.output") is False
pump(60)
ev(root, "flag = false")
pump(60)
ev(root, "flag = true")
pump(60)
assert ev(root, "gate.output") is False, "still bursting"
pump(120)
assert ev(root, "gate.output") is True and ev(root, "gate.settled") is True

# startSettled: false holds the first value back for the interval.
pump(150)
assert ev(root, "burst.settled") is True and ev(root, "burst.output.length") == 1
ev(root, 'screens = ["a", "b"]')
assert ev(root, "burst.settled") is False
pump(40)
ev(root, 'screens = ["b"]')
pump(60)
assert ev(root, "burst.settled") is False, "outputs still churning"
pump(120)
assert ev(root, "burst.settled") is True and ev(root, "burst.output.join()") == "b"

print("surface-latch: ok")
h.exit(0)
