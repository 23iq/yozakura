"""NotchViewTransition (opacity on the render thread) in a real window (GL,
private Xvfb): after a push and a pop the incoming view ends fully opaque
and the outgoing one transparent, with animations on and off (an Animator
of duration 0 never writes its value back; the transition must)."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.002)


h = Harness("notch-view-transition")
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 160 }")
h.module("qs.modules.theme", {"Motion": "pragma Singleton\nQtObject { property var emphasis: ({ easing: Easing.OutCubic }) }"})
h.module("qs.modules.notch", {"NotchViewTransition": (REPO / "modules/notch/NotchViewTransition.qml").read_text()})
root = h.load("""import QtQuick
import QtQuick.Controls
import qs.config
import qs.modules.notch
Item {
    width: 200; height: 100
    property alias stack: sv
    Component { id: page; Rectangle { color: "red" } }
    property var first: null
    property var second: null
    StackView {
        id: sv
        anchors.fill: parent
        pushEnter: NotchViewTransition { entering: true }
        pushExit: NotchViewTransition { entering: false }
        popEnter: NotchViewTransition { entering: true }
        popExit: NotchViewTransition { entering: false }
    }
    function pushPage() { const p = sv.push(page); return p; }
}""", auto_stub=False)

win = QQuickWindow()
win.resize(200, 100)
root.setParentItem(win.contentItem())
win.show()
pump(60)

for dur in (160, 0):
    h.eval(root, f"Config.animDuration = {dur}; stack.clear(); first = pushPage()")
    pump(400)
    h.eval(root, "second = pushPage()")
    pump(400)
    check(f"push (animDuration {dur}): the incoming view ends opaque", h.eval(root, "second.opacity") == 1,
          str(h.eval(root, "second.opacity")))
    check(f"push (animDuration {dur}): the outgoing view ends hidden",
          h.eval(root, "first.opacity === 0 || !first.visible"))
    h.eval(root, "stack.pop()")
    pump(400)
    check(f"pop (animDuration {dur}): the view underneath ends opaque", h.eval(root, "first.opacity") == 1,
          str(h.eval(root, "first.opacity")))

print("NotchViewTransition:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
