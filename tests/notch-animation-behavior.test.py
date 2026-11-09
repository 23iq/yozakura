"""NotchAnimationBehavior (the dashboard's open/close motion) on Animators,
in a real window (GL, private Xvfb): it scales and fades in while shown,
stays visible through the leave motion and only then hides, and with
animations off it switches at once."""
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


h = Harness("notch-animation-behavior")
h.singleton("qs.config", "Config", "QtObject { property int animDuration: 200 }")
h.module("qs.modules.theme", {
    "Motion": """pragma Singleton
QtObject {
    property QtObject morph: QtObject { property int easing: Easing.OutBack }
    property QtObject enter: QtObject { property int easing: Easing.OutCubic }
}""",
})
h.module("qs.modules.components", {"RenderFade": (REPO / "modules/components/RenderFade.qml").read_text()})
h.module("qs.modules.notch", {"NotchAnimationBehavior": (REPO / "modules/notch/NotchAnimationBehavior.qml").read_text()})
root = h.load("""import QtQuick
import qs.modules.notch
import qs.config
Item {
    width: 200; height: 100
    property alias view: v
    NotchAnimationBehavior { id: v; x: 50; y: 20; width: 100; height: 60; Rectangle { anchors.fill: parent; color: "red" } }
}""", auto_stub=False)

win = QQuickWindow()
win.resize(200, 100)
root.setParentItem(win.contentItem())
win.show()
pump(100)


def ev(expr):
    return h.eval(root, expr)


def red():
    c = win.grabWindow().pixelColor(100, 50)
    return c.red() > 200 and c.green() < 60


check("hidden at rest", not ev("view.visible") and not red())

ev("view.isVisible = true")
check("visible from the moment it opens", ev("view.visible"))
pump(400)
check("open: opaque, full size, drawn", ev("view.opacity") == 1 and ev("view.scale") == 1 and red())

ev("view.isVisible = false")
check("still visible as the leave motion starts", ev("view.visible"))
pump(60)
check("still visible mid-leave", ev("view.visible"))
pump(400)
check("hidden once the leave motion ends", not ev("view.visible") and ev("view.opacity") == 0 and not red())

# Animations off: switches at once, never lingers
ev("Config.animDuration = 0; view.isVisible = true")
pump(40)
check("animations off: open at once", ev("view.visible") and ev("view.opacity") == 1 and ev("view.scale") == 1)
ev("view.isVisible = false")
check("animations off: hidden at once", not ev("view.visible"))
pump(40)
check("animations off: done", ev("view.opacity") == 0 and ev("view.scale") == 0.8)

print("NotchAnimationBehavior:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
